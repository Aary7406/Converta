## ⚡ Converta

**A fast, offline media conversion tool built on top of FFmpeg and libvips, focused on performance and minimal overhead.**

---

### 🧠 Overview

Converta is designed to perform media transformations locally without relying on cloud APIs or heavy UI wrappers.  
It uses efficient native libraries and avoids unnecessary intermediate files to keep conversions fast and resource-efficient.

---

### 🚀 Key Features

#### 🖼️ Image Processing (libvips via FFI)
- Uses Dart FFI to interface with `libvips`
- Streaming-based processing reduces memory usage compared to traditional tools like ImageMagick
- Optimized for large images and batch operations

#### 🎬 Video & Audio Conversion (FFmpeg)
- CRF-based encoding for balanced quality and size
- VBR audio compression (`-q:a`) for efficient output
- Fast-start MP4 support for instant playback

#### 🎞️ GIF Optimization Pipeline
- Palette generation + reuse for better color accuracy
- Lanczos scaling to reduce artifacts and banding

#### 📦 Offline-First
- No cloud processing or API dependency
- Runs entirely on local hardware

---

### 🏗️ Architecture

- Built with **Flutter (Dart)** for a lightweight native UI
- Uses **FFmpeg** and **libvips** for core processing
- Designed to minimize disk I/O and unnecessary subprocess overhead

---

### 💻 Platform

- Windows 10 / 11 (.exe)
- Bundled native dependencies for consistent offline usage