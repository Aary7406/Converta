#pragma once

#include <stdint.h>

#ifdef CONVERTA_CORE_EXPORTS
#  define CONVERTA_API __declspec(dllexport)
#else
#  define CONVERTA_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*converta_progress_cb)(double progress, void* userdata);

/* Convert an animated GIF to MP4 using libx264.
   Returns 0 on success, -1 on failure. */
CONVERTA_API int32_t converta_gif_to_mp4(
    const char* in,
    const char* out,
    int32_t     crf,
    const char* preset,
    converta_progress_cb cb,
    void*       userdata);

/* Encode a JPEG/PNG/BMP image to AVIF.
   Returns 0 on success, -1 on failure. */
CONVERTA_API int32_t converta_encode_avif(
    const char* in,
    const char* out,
    int32_t     quality,
    int32_t     speed);

/* Decode an AVIF image to JPEG or PNG.
   Returns 0 on success, -1 on failure. */
CONVERTA_API int32_t converta_decode_avif(
    const char* in,
    const char* out,
    int32_t     jpeg_quality);

/* Signal the currently running operation to stop.
   Thread-safe; may be called from any thread. */
CONVERTA_API void converta_cancel(void);

/* Returns a pointer to the last error message string.
   Valid until the next converta_* call. Never NULL. */
CONVERTA_API const char* converta_last_error(void);

#ifdef __cplusplus
} // extern "C"
#endif
