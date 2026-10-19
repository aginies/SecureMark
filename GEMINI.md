# SecureMark Agent Development Guide

SecureMark is a professional Flutter application for high-security document distribution with visible watermarks, advanced invisible steganography, and AI-resistant protection layers.

## Quick Reference

- **Framework**: Flutter (Dart) - Multi-platform (Android, iOS, Windows, macOS, Linux, Web)
- **Core Tech**: Image processing (isolates), AES-256 encryption, DCT steganography, AI cloaking, Ed25519 digital signatures
- **Architecture**: Centralized logic in `lib/watermark_processor.dart`, UI in `lib/pages/watermark_page.dart`
- **Integrity**: On-device Ed25519 identity generation and SHA-256 document signing.
- **State**: Basic Flutter setState + SharedPreferences (no external state library)
- **Localization**: Multi-language (EN, FR, DE, ES, IT) using `.arb` files in `lib/l10n/`

---

## Build, Lint & Test Commands

### Essential Commands

```bash
# Install dependencies
flutter pub get

# Run application (hot reload enabled)
flutter run

# Run ALL tests
flutter test

# Run SINGLE test file
flutter test test/unit/watermark_processor_test.dart

# Run SINGLE test by name pattern
flutter test --name "Should report progress"

# Format code (auto-fix)
dart format .

# Check formatting (CI/validation)
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze

# Quality checks (format + analyze + test)
./build_and_verify.sh quality_checks

# Generate localization files
flutter gen-l10n
```

### Build Script (`./build_and_verify.sh`)

```bash
./build_and_verify.sh cleanup          # flutter clean
./build_and_verify.sh format_code      # Format all Dart files
./build_and_verify.sh quality_checks   # Format check + analyze + tests
./build_and_verify.sh generate_assets  # Regenerate icons + localizations
./build_and_verify.sh build_apk        # Build signed Android APK
./build_and_verify.sh build_aab        # Build signed Android App Bundle
./build_and_verify.sh build_ios        # Build iOS (macOS only)
./build_and_verify.sh build_macos      # Build macOS (macOS only)
./build_and_verify.sh build_windows    # Build Windows (Windows only)
./build_and_verify.sh build_web        # Build web (JS + WASM) → build/web/
```

---

## Code Style Guidelines

### 1. Import Organization

**Three-tier order** (separated by blank lines, sorted alphabetically within each tier):

```dart
// Tier 1: dart: imports (standard library)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Tier 2: package: imports (external dependencies)
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

// Tier 3: Relative imports (local files)
import 'font_manager.dart';
import 'models/processor_models.dart';
import 'steganography/lsb_handler.dart';
```

**Common aliases**: `as ui`, `as img`, `as p`, `as sync`

### 2. Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Classes | UpperCamelCase | `WatermarkProcessor`, `LsbHandler` |
| Public methods | lowerCamelCase | `processFile()`, `embedLSB()` |
| Private methods | `_lowerCamelCase` | `_imageIsolateEntry()`, `_addLog()` |
| Public variables | lowerCamelCase | `outputPath`, `steganographyVerified` |
| Private fields | `_lowerCamelCase` | `_transparency`, `_processing` |
| Controllers | suffix `Controller` | `_textController`, `_previewController` |
| Constants | `_lowerCamelCase` (private static) | `_maxCacheSize`, `headerBits` |
| Enum values | lowerCamelCase | `WatermarkType.text`, `PreviewMode.original` |

### 3. File Organization

```dart
// 1. Imports (dart:, package:, relative)
// 2. Class definition
class WatermarkProcessor {
  // 3. Static fields/constants
  static final Map<String, ProcessResult> _resultCache = {};
  
  // 4. Instance fields
  final String outputPath;
  
  // 5. Constructors
  const ProcessResult({required this.outputPath});
  
  // 6. Public static methods
  static Future<ProcessResult> processFile({...}) async {}
  
  // 7. Public instance methods
  void clearCache() {}
  
  // 8. Private methods (at bottom)
  static void _addToCache(String key, ProcessResult result) {}
}
```

**StatefulWidget pattern**:
Fields → Lifecycle (initState/dispose) → build() → Widget builders → Business logic

### 4. Type Usage

- **Explicit types preferred** over `var` (except obvious literals)
- **Nullable types (`?`)** over `late` keyword
- **Named parameters** with `required` for mandatory args
- **Const constructors** when possible

```dart
// Good
final Uint8List inputBytes = await file.readAsBytes();
final String? outputDirectory;
int? _targetSize = 1280;

// Acceptable (obvious type)
var currentByte = 0;

// Avoid
late Uint8List _hiddenFileBytes;  // Prefer nullable: Uint8List?
```

### 5. Async Patterns

- **Future-based** async (99% of code) - Stream only for isolate/PDF rasterization
- **Isolate.spawn** for heavy computation (>100ms)
- **Isolate.run** for simple background tasks
- **Always check `mounted`** before setState in async callbacks

```dart
// Heavy computation pattern
await Isolate.spawn(_imageIsolateEntry, params);
final result = await completer.future;

// Mounted check pattern
if (mounted) {
  setState(() { _processing = false; });
}
```

### 6. Error Handling

- **Custom exceptions** (`WatermarkError`) with structured types
- **Rethrow** custom errors, wrap unexpected errors
- **Validate before processing** (file size, type, etc.)
- **No Result<T, E> pattern** - uses exceptions for error flow

```dart
try {
  // operation
} catch (e) {
  if (e is WatermarkError) rethrow;
  throw WatermarkError(
    type: WatermarkErrorType.invalidImageData,
    message: 'Failed to process image',
    filePath: file.path,
    originalError: e,
  );
}
```

### 7. Documentation

- **Triple-slash `///`** for public API documentation
- **Double-slash `//`** for inline implementation comments
- **Focus on "why"**, not "what" (code is self-documenting)
- **No JavaDoc tags** (@param, @return)

```dart
/// Encrypts a signature for embedding in PDF metadata
static Uint8List encryptSignatureForPdf(String signature, String? password) {
  // Optimization: Pre-compute salt to avoid repeated hashing
  final salt = sha256.convert(utf8.encode(signature)).bytes;
}
```

---

## Development Conventions

### Performance Rules

- **Heavy processing** (>100ms) MUST use Isolate (in `watermark_processor.dart`)
- **Optimize hot paths**: Pre-compute, cache, use lookup tables (see DCT optimization)
- **TransferableTypedData** for large byte arrays in isolate communication
- **Pre-render TTF stamps** on main thread before isolate spawn

### Testing Rules

- **Unit tests** in `test/unit/` for core logic
- **Widget tests** in `test/` for UI components
- **Always run tests** before committing: `./build_and_verify.sh quality_checks`
- **Print statements** acceptable for debugging (no logger framework used)
- Current status: **32 tests passing, 0 failures**

### Localization Rules

- **Always update ALL `.arb` files** in `lib/l10n/` (EN, FR, DE, ES, IT)
- **Run `flutter gen-l10n`** after updating strings
- **Use AppLocalizations**: `final l10n = AppLocalizations.of(context)!;`

### State Management

- **setState** for UI updates (no Provider/Bloc/Riverpod/GetX)
- **SharedPreferences** for persistence
- **Check `mounted`** before setState in async callbacks
- **Static cache** for processor results (`_resultCache`)

### Security & Privacy

- **Offline-first**: All processing strictly local (no network calls)
- **AES-256 encryption** for steganography passwords
- **Document scanning** remains on-device
- **No telemetry or analytics**

---

## Important Notes for Agents

1. **Maintain zero errors** in `flutter analyze`
2. **Format before committing**: `dart format .`
3. **Heavy computation MUST use isolates** - never block UI thread
4. **Update all 5 languages** when adding UI strings
5. **Follow modern Dart** - use switch expressions, records, pattern matching
6. **Preserve performance optimizations** - DCT lookup tables, grayscale pre-computation, zero-copy transfers
7. **Test on real devices** for performance validation (especially steganography/AI features)
8. **Document "why" not "what"** - code should be self-explanatory

---

## Key Architecture Decisions

- **Centralized processor**: `lib/watermark_processor.dart` handles all watermarking logic
- **Isolate-based**: Heavy processing isolated to prevent UI jank
- **Stateless preferences**: Settings persisted via SharedPreferences
- **No external state library**: Pure Flutter state management
- **Cache-friendly**: Result caching with LRU eviction (max 10 entries)
- **Type-safe**: Explicit types, nullable types, no dynamic abuse

---

**Quick Health Check**: `./build_and_verify.sh quality_checks` should pass with 0 errors, 32 tests passing.
