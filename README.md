# SecureMark

SecureMark is a professional Flutter application designed to secure documents and images with visible watermarks and advanced invisible steganography before sharing them.

The project is designed for high-security document distribution: choose files, apply multi-layered protection, preview results, and securely share them.

![App Screenshot](/images/app.jpg)

## Core Features Overview

- **Settings Profiles**: One-tap presets (**Custom, Identity, Image, Doc, QR Code**) for instant workflow configuration.
- **AI Protection Suite**: 
    - **Anti-AI Removal Protection**: Position and alpha jitter to prevent AI from learning and erasing watermarks.
    - **AI Cloaking (Adversarial)**: Injects invisible noise to disrupt AI style extraction and block OCR scrapers.
- **Multi-layer Steganography**: 3 independent invisible methods (LSB text, hidden file, and robust DCT).
- **Advanced File Management**: Manage large batches with a dedicated selection modal featuring PDF first-page previews and easy removal.
- **Batch Processing**: Background threading (Isolates) with linear, granular progress tracking.
- **Built-in Analyzer**: Detect and extract hidden signatures or embedded files with AES-256 decryption.
- **Cross-platform**: Android share intents, iOS export, and desktop drag-and-drop support.

## User Interface & Workflow

### Main Interface

- **Profile Selector**: High-visibility horizontal chips for rapid switching between security presets.
- **Interactive Preview**: 
  - **Smart Zoom**: Double-tap to zoom at specific coordinates for detailed inspection.
  - **A/B Toggle**: Quickly compare the original vs. protected result (images only).
  - **Live Shader**: Real-time preview of transparency and color effects.
- **Merged Controls**: Status icons are now integrated directly into the styling cards to maximize vertical space.

### File Input & Management

- **Selected Files Modal**: Click the "Selected files" label to open a grid view of all pending files with thumbnails and individual "remove" buttons.
- **Fast PDF Previews**: Thumbnails for PDF files are generated instantly using the first page.
- **Loading Feedback**: Immediate visual feedback during file selection and preparation.
- **Input Variety**: Support for File Picker, Scan Document (with edge detection), Desktop Drag & Drop, and Android Share Intents.

### Specialized Dialogs

1. **File Analyzer**: Detect and extract hidden signatures, robust watermarks, and embedded files
2. **Steganography Options**: Configure LSB text signature and hidden file embedding with AES-256 encryption
3. **QR Watermark Options**: Configure QR code type, position, size, and opacity
4. **Expert Options**: Advanced settings for quality control, anti-AI protection, and output customization
5. **Logs Viewer**: Real-time application logs (100 most recent) with export capability
6. **About Dialog**: Version information and project details
7. **Processing Progress**: Real-time progress updates during batch operations
8. **Save Results**: File naming and location selection with preview

## Watermarking Capabilities

### Visible Watermarks

**Before:**
![Original Image](images/image.jpg)

**After - Text Watermark:**
![Text Watermark Example](images/image_with_text.jpg)

- **Text Watermarks**: Custom text with automatic timestamp injection
- **Image/Logo Watermarks**: Brand logo overlay with preserved aspect ratio

![Logo Watermark Example](images/image_with_logo.jpg)
- **Transparency Control**: 0-100% opacity adjustment
- **Density Control**: Adaptive placement algorithm (8-max instances based on image dimensions)
- **Rotation**: Random 15° step rotations for anti-pattern AI protection
- **Color Options**:
  - Random HSV color generation with 6 color variations per watermark
  - Custom color picker with RGB selection
  - Per-watermark color variation support

### Smart Placement Algorithm

- **Grid-based Positioning**: Automatic cell calculation (rows × columns) based on image size
- **Random Jitter**: Positioning variation within cells for natural appearance
- **Collision Avoidance**: Retry logic (6 attempts per cell, 12 global) to prevent overlap
- **Adaptive Density**: Watermark count scales with image dimensions

### Font Rendering

- **Bitmap Font Support**: Arial rendered at 14pt/24pt/48pt for system compatibility
- **TrueType Rendering**: Flutter canvas-based rendering for all other fonts
- **Stamp Caching**: Pre-rendered watermark stamps cached per font-size combination
- **Colorization**: Efficient colorization at composite time

### PDF Support

- **Vector Watermarking**: Native PDF graphics layer insertion (background mode) preserves text quality
- **Raster Fallback**: Automatic page-by-page rasterization for malformed PDFs
- **Multi-page Processing**: Iterate through all pages in PDF documents
- **Preview Generation**: First page rendered at 72 DPI for preview display

## Advanced Security & Steganography

SecureMark implements three independent invisible protection layers.

![Steganography Protection](images/with_steganography.jpg)

### 1. LSB Text Signature

**Purpose**: Embed invisible text signature for ownership verification

### 2. Hidden File Embedding

**Purpose**: Embed entire secondary files (documents, images, archives) within the image

### 3. Robust DCT Watermarking

**Purpose**: Persistent signature that survives image transformations (compression, resizing, etc.)

### Unified File Analyzer

The File Analyzer scans to find Steganography.

## QR Code Integration

SecureMark can embed QR codes watermarks with three content types:

### QR Code Types

#### 1. Metadata (JSON)
Standard SecureMark metadata format:
- **Author**: Document creator name
- **URL**: Reference website or source
- **Timestamp**: ISO 8601 format generation time
- **App Info**: SecureMark identifier and version
- **Toggles**: Individual field enable/disable
- **Format**: Compact JSON encoding

#### 2. URL (Website Redirect)
Direct website link encoding:
- **Use Case**: Product pages, documentation, verification portals
- **Format**: Plain URL string (https://...)
- **Scanning**: Opens directly in mobile browsers

#### 3. vCard (Contact Information)
vCard 3.0 format for professional contact sharing:
- **Fields**:
  - Full Name (First + Last)
  - Organization
  - Phone Number (TYPE=CELL)
  - Email Address (TYPE=INTERNET)
  - Website URL
  - Physical Address
- **Format**: Standard vCard 3.0 specification
- **Compatibility**: Works with all major contact apps (iOS Contacts, Google Contacts, Outlook)

### Visual Configuration

- **Position**: 5 options (Top-Left, Top-Right, Bottom-Left, Bottom-Right, Center)
- **Size**: 50-200 pixels (scalable)
- **Opacity**: 0.0-1.0 (fully transparent to fully opaque)
- **Margin**: 20-pixel automatic margin from edges
- **Error Correction**: Level H (High - 30% recovery)
- **Mode Toggle**: Visible QR watermark or invisible (metadata-only)

## Font System

SecureMark provides 22 font options from three sources with intelligent loading and caching:

### System Fonts (1 option)
- **Arial** (System Default) - Bitmap rendering at 3 sizes (14pt, 24pt, 48pt)

### Google Fonts (9 options)
Dynamically downloaded from Google Fonts API:
- **Roboto** (Modern, sans-serif)
- **Open Sans** (Clean, highly legible)
- **Lato** (Professional, business-friendly)
- **Montserrat** (Bold, geometric)
- **Poppins** (Rounded, friendly)
- **Noto Sans** (Universal, multi-language support)
- **Source Code Pro** (Monospace, technical)
- **Playfair Display** (Elegant, serif)
- **Oswald** (Strong, condensed)

### Custom TTF Fonts (6 options)
Pre-bundled in application assets:
- **Charis SIL** (Serif, academic)
- **Liberation Mono** (Monospace, open-source)
- **Liberation Serif** (Traditional, book-style)
- **Bitstream Vera Sans** (Classic, clean)
- **Custom Roboto** (Local TTF version)
- **Custom Open Sans** (Local TTF version)

### Font Rendering Architecture

- **Bitmap Rendering**: Arial only, using image package's built-in bitmap fonts (14/24/48pt)
- **TrueType Rendering**: All other fonts rendered via Flutter Canvas API
  - Pre-rendered stamps cached per font-size combination
  - Colorized at composite time for efficiency
  - Fallback to bitmap if TTF rendering fails

### Font Caching System

- **LRU Cache**: Least Recently Used eviction strategy
- **Maximum Cache Size**: 50 MB
- **Cache Scope**: Font bytes stored per font (not per size)
- **Pre-loading**: Common fonts (Roboto, Open Sans) pre-loaded at startup
- **Sources**:
  1. System bitmap (immediate)
  2. Local assets (fast, bundled TTF files)
  3. Google Fonts API (network download, cached after first use)

## How It Works

1. Enter the watermark text or configure a QR code.
2. Pick files (images or PDFs) or drag and drop them.
3. (Optional) Configure Steganography to hide secret data or files.
4. Adjust visibility settings (Transparency, Density, Font).
5. Click `Apply SecureMark`.
6. Preview the result (with A/B comparison) and verify the hidden signatures.
7. Save or share the protected outputs.

## Export & Processing Options

### Batch Processing

![Processing Progress](images/progress.jpg)

- **Background Isolation**: All heavy processing runs in Dart Isolates (separate threads) using `SendPort` for safe communication.
- **Linear Progress Tracking**: Completely redesigned progress bar showing granular steps (Loading, Anti-AI, Watermarking, etc.).
- **Multilingual Support**: All progress status messages are fully localized (EN, FR, DE, IT).
- **Cancellation Token**: Graceful cancellation support during processing.
- **Result Caching**: LRU cache (max 10 results) to avoid reprocessing identical requests.

### Quality Control

- **JPEG Quality**: Adjustable 1-100 (default: 75)
- **WebP Quality**: Adjustable 1-100 (default: 75)
- **PNG Compression**: Level 2 (balanced speed/size) for lossless steganography
- **Format Preservation**:
  - HEIC/HEIF → JPEG conversion
  - Original format maintained when possible
  - Forced PNG output when steganography is enabled (lossless requirement)

### Target Size & Resizing

- **Auto-resize**: Intelligent downscaling for mobile-friendly sharing
- **Target Size**: User-defined maximum dimension (e.g., 2048px)
- **Aspect Ratio**: Always preserved during resize
- **Interpolation**: Average interpolation for quality preservation
- **Memory Protection**: Automatic fallback on memory limit exceeded errors

### Output Customization

- **File Prefix**: Customizable (default: `securemark-`)
- **Timestamp Injection**:
  - Optional filename timestamp: `-YYYYMMDD-HHMM` suffix
  - Automatic watermark text timestamp: appended to user text
  - Format: `YYYY-MM-DD HH:MM:SS`
- **Extension Preservation**: Maintains original file extension (or upgrades format)
- **Metadata Options**:
  - Strip original metadata (default for privacy)
  - Preserve original EXIF/metadata (optional)
  - Inject SecureMark identification in metadata

### Anti-AI Removal Protection

- **Purpose**: Disrupt AI model training and prevent automated watermark erasure.
- **Level**: 0-100% intensity slider.
- **Implementation**:
  - **Position Jitter**: Random ±10px offset per watermark (scaled by level).
  - **Angle Jitter**: Random ±15° rotation variation (scaled by level).
  - **Alpha Jitter**: Random ±40 alpha channel variation per pixel (scaled by level).
  - **Non-deterministic**: Different output each time at same settings.

### AI Cloaking (Adversarial)

- **Purpose**: Protect the artistic style of images and block OCR (text recognition) by scraping bots.
- **Mechanism**: Injects high-frequency noise in the DCT domain.
- **Effect**: Invisible to human eyes, but causes AI models to misidentify content or fail to extract text data.

### PDF Handling

- **Vector Engine**: Direct PDF graphics layer insertion (preserves text/vector quality)
- **Raster Fallback**: Automatic page-by-page image conversion for corrupted PDFs
- **Rasterization Option**: Force rasterization for maximum security (converts to images)
- **Page Iteration**: Supports multi-page PDF watermarking
- **Preview Generation**: First page rendered at 72 DPI for preview display

## Platform Integration

### Android Sharing Integration

SecureMark registers as a share target for image and PDF files:

**Intent Filters**:
- `ACTION_SEND` - Single file sharing
  - Accepts: `image/*` (all image types)
  - Accepts: `application/pdf`
- `ACTION_SEND_MULTIPLE` - Multiple file sharing
  - Accepts: `image/*` (batch image processing)

**File Handling**:
- **Content URI Resolution**: Automatic conversion from `content://` URIs to file paths
- **Extension Preservation**: MIME type detection and filename extension recovery
- **Supported Formats**:
  - `image/jpeg` → `.jpg`
  - `image/png` → `.png`
  - `image/webp` → `.webp`
  - `image/heic` → `.heic`
  - `image/heif` → `.heif`
  - `application/pdf` → `.pdf`
- **Cache Directory**: Temporary files copied to app cache with unique naming
- **Intent History Filter**: Prevents re-processing of historical intents

**Platform Channel**:
- **Channel Name**: `secure_mark/sharing`
- **Methods**:
  - `getSharedFiles()`: Returns list of file paths from share intent
  - `clearSharedFiles()`: Clears shared file queue
  - `onSharedFilesReceived(count)`: Callback to Flutter when files arrive

**Workflow**:
1. User selects "Share to SecureMark" from another app
2. Android system launches SecureMark with SEND/SEND_MULTIPLE intent
3. MainActivity extracts URIs and converts to accessible file paths
4. Files are cached in app-specific directory with original extensions
5. Flutter layer is notified via method channel callback
6. Files are automatically loaded into the watermarking interface

### iOS Integration

- **share_plus Plugin**: Cross-platform sharing API
- **File Export**: Share processed files to iOS Share Sheet
- **Permissions**: Photo library access for image picker integration

### Desktop Support

- **Drag & Drop**: desktop_drop package for file dragging (Windows, macOS, Linux)
- **File Selector**: Native file picker dialogs on all desktop platforms
- **Path Provider**: Cross-platform temporary and document directory access

## Supported Input Formats

- **PNG** - Lossless compression
- **JPG / JPEG** - With adjustable quality control
- **WebP** - Modern format with quality control
- **HEIC / HEIF** - Native support for modern mobile photo formats
- **PDF** - Vector or rasterized (flattened) processing

## Development & Testing

Install dependencies:
```bash
flutter pub get
```

Run the application:
```bash
flutter run
```

Run security & steganography tests:
```bash
flutter test test/unit/steganography_test.dart
```

## Project Goal

SecureMark focuses on providing verifiable proof of ownership and secure distribution for shared documents. It bridges the gap between simple visual watermarking and advanced forensic steganography.

## License

This project is licensed under the GNU General Public License v3.0. See `LICENSE` for details.
