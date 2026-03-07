<div align="center">

# 🌊 Converta
**A high-performance, strictly-offline media converter for Windows.**

Built with Flutter, this converter trades standard OS UI elements for an immersive, highly optimized visual experience — featuring a true AMOLED digital rain background and a clear liquid glass aesthetic. 

Under the hood, it abandons standard cloud-based APIs in favor of raw C-library power, bundling FFmpeg and `libvips` directly into the app for multi-threaded, localized processing that leverages your CPU's maximum output.

</div>

---

### 🔥 Key Features

#### ⚡ Extreme Performance Backend
* **In-Process Image Conversion:** Image-to-image conversions (PNG, JPG, WebP, BMP, TIFF) run through **`libvips` via Dart FFI**, making it 5-10x faster than standard subprocess tools (like ImageMagick). It processes images on a demand-driven pipeline using all available CPU cores.
* **Lossless Image Tech:** Implements `deflate` compression for TIFFs, max compression 9 for PNGs, and true lossless mode for WebP.
* **FFmpeg Multi-threading:** Video and Audio streams are mapped directly to FFmpeg with `veryfast` presets, Variable Bitrate (VBR) audio targeting, and Constant Rate Factor (CRF) quality controls.
* **100% Offline:** Absolutely no cloud processing. All heavy lifters (`libvips.dll`, `ffmpeg.exe`, `magick.exe`) execute locally.

#### 🎨 Custom Visual Engine
* **Matrix Digital Rain:** A custom-built, 60fps-locked matrix rain animation rendering directly on the Canvas. Uses a highly optimized GPU Glyph Atlas to entirely bypass CPU text layout costs, maintaining maximum app performance even under high visual load.
* **AMOLED Deep Black:** Built specifically for OLED/AMOLED screens. Pure `#000000` pitch black background allowing the UI elements to pop.
* **Clear Liquid Glass:** Built using the `adaptive_platform_ui` package, the UI strips away standard frosted glass. It uses `systemUltraThinMaterial` blur styling, giving cards the surface tension and deep refraction of a clear drop of water over the matrix rain.

#### 🛠️ Advanced Conversion Capabilities
* **Cross-Medium Porting:** Strip audio directly from video files, or extract a specific still frame (`.jpg`/`.png`) straight from an `.mp4`.
* **Pro-Grade GIF Generation:** Doesn't just dump video to GIF. Generates a custom 256-color palette in pass 1, then leverages that palette in pass 2 to drastically cut down file sizes while eliminating color banding and dithering.
* **Multi-Page TIFF Stacking:** Select multiple images (or a sequence) at once, and the app will stack them vertically, generating a lossless, multi-page `.tiff` file in seconds.

### 🖥️ Installation & Development

This project was developed for **Windows 10/11**.

**Requirements:**
- Flutter SDK (3.x+)
- Windows developer setup (Visual Studio C++ build tools)

**Running locally:**
```bash
flutter pub get
flutter run -d windows
```

### 🧠 Tech Stack
- **Framework:** Flutter (Dart)
- **High-Speed UI Rendering:** `adaptive_platform_ui`
- **Native Bindings:** `libvips_ffi`
- **Conversion Engines:** FFmpeg & ImageMagick (Subprocess routing)
