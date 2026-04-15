#include "../include/converta.h"
#include "../include/thread_pool.h"

#include <string>

static std::string g_last_error;

static void set_error(const char* msg) {
    g_last_error = msg ? msg : "";
}

int32_t converta_gif_to_mp4(
    const char* in,
    const char* out,
    int32_t     crf,
    const char* preset,
    converta_progress_cb cb,
    void*       userdata)
{
    (void)in; (void)out; (void)crf; (void)preset; (void)cb; (void)userdata;
    set_error("converta_gif_to_mp4: not implemented");
    return -1;
}



void converta_cancel(void) {
    g_cancel.store(true, std::memory_order_relaxed);
}

const char* converta_last_error(void) {
    return g_last_error.c_str();
}
