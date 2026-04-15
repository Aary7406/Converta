#pragma once

#include <atomic>
#include <condition_variable>
#include <functional>
#include <future>
#include <mutex>
#include <queue>
#include <thread>

/// Single-worker FIFO job queue.
///
/// Design notes:
///   - One background thread processes jobs sequentially.
///   - Jobs are std::function<int32_t()> returning a result via std::future.
///   - g_cancel is a global atomic checked by encode loops; converta_cancel()
///     sets it true. The worker resets it to false before each new job.
///   - Designed so the worker count can be increased later without API changes.

// Global cancel flag — checked inside encode loops.
extern std::atomic<bool> g_cancel;

struct ThreadPool {
    ThreadPool();
    ~ThreadPool();

    /// Enqueue a job. Returns a future the caller can wait on.
    /// Jobs run in FIFO order on the single worker thread.
    std::future<int32_t> enqueue(std::function<int32_t()> job);

    /// Stop accepting new jobs and join the worker thread.
    void shutdown();

private:
    struct Job {
        std::function<int32_t()>  fn;
        std::promise<int32_t>     promise;
    };

    std::thread              _worker;
    std::queue<Job>          _queue;
    std::mutex               _mutex;
    std::condition_variable  _cv;
    bool                     _stop = false;

    void _run();
};

/// Singleton accessor — one pool for the whole DLL lifetime.
ThreadPool& job_pool();
