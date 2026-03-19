# Watermark App

Watermark App is a Flutter application for adding visible watermarks to images and PDF documents before sharing them.

The project is designed for lightweight document distribution workflows: choose one or more files, preview the result, adjust watermark settings, then save or share the processed outputs.

Author: Antoine Ginies

## Features

- Add watermarks to images and PDF files
- Process multiple files in one batch
- Preview processed results with swipe navigation
- Adjust watermark transparency (default 75%), color, density, and font size
- **Multiple font support**: Choose from 16 different fonts including Google Fonts and custom TTF fonts
- **Extensive color palette**: 10 color options including red, blue, green, orange, pink, cyan, yellow, white, purple, and black
- **Random or fixed color modes** for varied watermark appearances
- Share generated files with available applications
- Resize image output for faster sharing workflows
- Desktop drag-and-drop support on supported platforms
- **Expert settings** for fine-tuned control over watermark appearance
- **Multilingual support** (English and French)

## Supported Input Formats

- **PNG** - Lossless compression
- **JPG / JPEG** - With adjustable quality control
- **WebP** - Modern format with quality control
- **PDF** - Rasterized processing

## Font Options

### System Fonts
- Arial (System Default)

### Google Fonts
- Roboto (Modern)
- Open Sans (Clean)
- Lato (Professional)
- Montserrat (Bold)
- Poppins (Rounded)
- Noto Sans (Universal)
- Source Code Pro (Monospace)
- Playfair Display (Elegant)
- Oswald (Strong)

### Custom TTF Fonts
Add your own fonts by placing TTF files in the `assets/fonts/` directory. Pre-configured support for:
- Custom Roboto
- Custom Open Sans
- Charis SIL (Serif)
- Liberation Mono (Monospace)
- Liberation Serif (Traditional)
- Bitstream Vera Sans

## How It Works

1. Enter the watermark text
2. Pick one or more image or PDF files (drag & drop supported)
3. Choose your preferred font style and color
4. Adjust watermark transparency (75% default), density, and other settings in Expert Options
5. Click `Apply Watermark`
6. Swipe through previews to review results
7. Save or share the generated files

## Expert Settings

Access advanced watermark customization:
- **Font Style**: Choose from 16 different fonts
- **Color Selection**: Fixed color or random color mode
- **Watermark Transparency**: Adjust visibility (75% default)
- **Font Size**: Control text size
- **JPEG/WebP Quality**: Optimize file size vs quality
- **Target Size**: Resize images for faster sharing
- **Timestamp**: Add creation timestamp to filenames

## Platforms

This project is built with Flutter and can target multiple platforms, including:

- Linux
- Android
- iOS / iPadOS
- macOS
- Windows
- Web

Platform support depends on your local Flutter toolchain and native SDK setup.

## Development

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Example for Linux:

```bash
flutter run -d linux
```

Build examples:

```bash
flutter build apk
flutter build appbundle
flutter build ios
```

## Project Goal

The application focuses on fast, practical watermarking for shared documents rather than archival-quality rendering. It favors smaller output size, quicker previews, and simple distribution through save and share actions.

## License

This project is licensed under the GNU General Public License v3.0. See `LICENSE` for details.
