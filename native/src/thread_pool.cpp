#include "../include/thread_pool.h"

// ─── Global cancel flag ───────────────────────────────────────────────────────
// Defined here (one translation unit). Declared extern in thread_pool.h so
// encode loops in avif_codec.cpp and gif_to_mp4.cpp can include and check it.
std::atomic<bool> g_cancel{false};

// ─── ThreadPool ───────────────────────────────────────────────────────────────

ThreadPool::ThreadPool() {
    _worker = std::thread(&ThreadPool::_run, this);
}

ThreadPool::~ThreadPool() {
    shutdown();
}

std::future<int32_t> ThreadPool::enqueue(std::function<int32_t()> fn) {
    Job job;
    job.fn = std::move(fn);
    auto future = job.promise.get_future();

    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (_stop) {
            // Pool is shutting down — reject by returning a failed result.
            job.promise.set_value(-1);
            return future;
        }
        _queue.push(std::move(job));
    }
    _cv.notify_one();
    return future;
}

void ThreadPool::shutdown() {
    {
        std::lock_guard<std::mutex> lock(_mutex);
        _stop = true;
    }
    _cv.notify_all();
    if (_worker.joinable()) {
        _worker.join();
    }
}

void ThreadPool::_run() {
    while (true) {
        Job job;

        {
            std::unique_lock<std::mutex> lock(_mutex);
            // Block until there is work or we are asked to stop.
            _cv.wait(lock, [this] {
                return _stop || !_queue.empty();
            });

            if (_stop && _queue.empty()) return;

            job = std::move(_queue.front());
            _queue.pop();
        }

        // Reset cancel flag before each job so a previous cancellation does
        // not bleed into the next queued job.
        g_cancel.store(false, std::memory_order_relaxed);

        int32_t result = -1;
        try {
            result = job.fn();
        } catch (...) {
            // Never let an exception escape the worker thread.
        }

        job.promise.set_value(result);
    }
}

// ─── Singleton ────────────────────────────────────────────────────────────────

ThreadPool& job_pool() {
    // Constructed on first call; destroyed when the DLL unloads.
    static ThreadPool pool;
    return pool;
}
