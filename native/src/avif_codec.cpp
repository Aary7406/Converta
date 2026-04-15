#define _CRT_SECURE_NO_WARNINGS
#include "../include/converta.h"

#include <avif/avif.h>
#include <string>
#include <cstring>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

static std::string g_last_error;

static void set_error(const char* msg) {
    g_last_error = msg ? msg : "";
}

// ─── encode ──────────────────────────────────────────────────────────────────

int32_t converta_encode_avif(
    const char* in,
    const char* out,
    int32_t     quality,
    int32_t     speed)
{
    if (!in || !out) { set_error("null path"); return -1; }

    // Clamp inputs defensively
    if (quality < 0)   quality = 0;
    if (quality > 100) quality = 100;
    if (speed < 0)     speed = 0;
    if (speed > 10)    speed = 10;

    // ── 1. Decode source image (JPEG / PNG / BMP) ─────────────────────────
    int w, h, channels;
    // Force RGBA (4 channels) so the libavif pipeline is uniform.
    unsigned char* pixels = stbi_load(in, &w, &h, &channels, 4);
    if (!pixels) {
        set_error(stbi_failure_reason());
        return -1;
    }

    // ── 2. Create avifImage ───────────────────────────────────────────────
    // YUV444 at max quality (less chroma subsampling = better fidelity).
    // YUV420 otherwise — good trade-off and required for very large images
    // to avoid hitting memory limits with the dav1d encoder.
    const avifPixelFormat pixFmt =
        (quality == 100) ? AVIF_PIXEL_FORMAT_YUV444 : AVIF_PIXEL_FORMAT_YUV420;

    avifImage* image = avifImageCreate(w, h, 8, pixFmt);
    if (!image) {
        stbi_image_free(pixels);
        set_error("avifImageCreate failed");
        return -1;
    }

    // ── 3. Fill RGBA planes ───────────────────────────────────────────────
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, image);
    rgb.format  = AVIF_RGB_FORMAT_RGBA;
    rgb.depth   = 8;
    rgb.rowBytes = (uint32_t)(w * 4);
    rgb.pixels  = pixels;

    avifResult res = avifImageRGBToYUV(image, &rgb);
    stbi_image_free(pixels); // pixels copied into YUV planes — free immediately

    if (res != AVIF_RESULT_OK) {
        set_error(avifResultToString(res));
        avifImageDestroy(image);
        return -1;
    }

    // ── 4. Encode ─────────────────────────────────────────────────────────
    avifEncoder* encoder = avifEncoderCreate();
    if (!encoder) {
        set_error("avifEncoderCreate failed");
        avifImageDestroy(image);
        return -1;
    }

    encoder->quality        = quality; // 0-100 maps directly
    encoder->qualityAlpha   = quality;
    encoder->speed          = speed;   // 0 = slowest/best, 10 = fastest

    // tune=iq gives better perceptual quality via variance-based quantiser
    avifEncoderSetCodecSpecificOption(encoder, "tune", "iq");

    avifRWData output = AVIF_DATA_EMPTY;
    res = avifEncoderWrite(encoder, image, &output);
    avifEncoderDestroy(encoder);
    avifImageDestroy(image);

    if (res != AVIF_RESULT_OK) {
        set_error(avifResultToString(res));
        avifRWDataFree(&output);
        return -1;
    }

    // ── 5. Write to disk ──────────────────────────────────────────────────
    FILE* fp = fopen(out, "wb");
    if (!fp) {
        set_error("cannot open output file for writing");
        avifRWDataFree(&output);
        return -1;
    }
    fwrite(output.data, 1, output.size, fp);
    fclose(fp);
    avifRWDataFree(&output);

    g_last_error.clear();
    return 0;
}

// ─── decode ──────────────────────────────────────────────────────────────────

int32_t converta_decode_avif(
    const char* in,
    const char* out,
    int32_t     jpeg_quality)
{
    if (!in || !out) { set_error("null path"); return -1; }

    if (jpeg_quality < 1)   jpeg_quality = 1;
    if (jpeg_quality > 100) jpeg_quality = 100;

    // ── 1. Read AVIF file into memory ─────────────────────────────────────
    FILE* fp = fopen(in, "rb");
    if (!fp) { set_error("cannot open input AVIF file"); return -1; }

    fseek(fp, 0, SEEK_END);
    long fileSize = ftell(fp);
    rewind(fp);

    avifRWData raw = AVIF_DATA_EMPTY;
    // avifRWDataRealloc allocates the buffer; avifRWDataFree cleans it up.
    avifRWDataRealloc(&raw, (size_t)fileSize);
    fread(raw.data, 1, (size_t)fileSize, fp);
    fclose(fp);

    // ── 2. Decode YUV planes ──────────────────────────────────────────────
    avifDecoder* decoder = avifDecoderCreate();
    if (!decoder) {
        avifRWDataFree(&raw);
        set_error("avifDecoderCreate failed");
        return -1;
    }

    // dav1d is faster than the default libaom for decode-only paths
    decoder->codecChoice = AVIF_CODEC_CHOICE_DAV1D;

    avifResult res = avifDecoderSetIOMemory(decoder, reinterpret_cast<const uint8_t*>(raw.data), raw.size);
    if (res == AVIF_RESULT_OK) {
        res = avifDecoderParse(decoder);
    }
    if (res == AVIF_RESULT_OK) {
        res = avifDecoderNextImage(decoder);
    }
    avifRWDataFree(&raw);

    if (res != AVIF_RESULT_OK) {
        set_error(avifResultToString(res));
        avifDecoderDestroy(decoder);
        return -1;
    }

    avifImage* image = decoder->image; // owned by decoder, do NOT destroy separately

    // ── 3. Convert to RGBA ────────────────────────────────────────────────
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, image);
    rgb.format = AVIF_RGB_FORMAT_RGBA;
    rgb.depth  = 8;
    avifRGBImageAllocatePixels(&rgb);

    res = avifImageYUVToRGB(image, &rgb);
    if (res != AVIF_RESULT_OK) {
        set_error(avifResultToString(res));
        avifRGBImageFreePixels(&rgb);
        avifDecoderDestroy(decoder);
        return -1;
    }

    // ── 4. Write output (JPEG or PNG by extension) ────────────────────────
    const char* ext = strrchr(out, '.');
    int writeOk = 0;

    if (ext && (strcmp(ext, ".jpg") == 0 || strcmp(ext, ".jpeg") == 0)) {
        writeOk = stbi_write_jpg(
            out, (int)rgb.width, (int)rgb.height, 4,
            rgb.pixels, jpeg_quality);
    } else {
        // Default to PNG for all other targets (lossless)
        writeOk = stbi_write_png(
            out, (int)rgb.width, (int)rgb.height, 4,
            rgb.pixels, (int)rgb.rowBytes);
    }

    avifRGBImageFreePixels(&rgb);
    avifDecoderDestroy(decoder);

    if (!writeOk) {
        set_error("stbi_write failed");
        return -1;
    }

    g_last_error.clear();
    return 0;
}
