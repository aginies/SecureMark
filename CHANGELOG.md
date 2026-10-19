# Changelog

All notable changes to SecureMark are documented in this file.

## Unreleased

### Changed

- Web UI: the "Analyse File" top-bar button, the Expert mode and Digital
  Integrity Signature settings, and the Digital Integrity Signature and Hide
  File options in the left panel are hidden on the web. Digital signing and
  file hiding are also forced off on the web so settings persisted on another
  platform cannot linger invisibly. The web app defaults to French unless the
  user explicitly chooses a language.
- Web UI (security): config Export/Import and the View Logs / Save Logs
  entries are hidden on the web. The backup zip contains the identity
  private key, and handing it or the log to the browser as a downloaded
  file is an unnecessary exposure on a shared machine. The in-app log
  dialog stays reachable from the error banner for on-screen diagnostics.

### Added

- Web deployment limits: files are rejected above 10 MB, sessions are
  capped at 5 files, and all in-memory file data (picked + generated)
  is erased 2 minutes after the last pick or processing run, with a
  visible countdown banner warning the user to download results before
  the data is gone.
- Web output: on the web the processed files are handed to the browser as a
  download — a single file directly, several files (or the zip option) as one
  `securemark-files-<timestamp>.zip`. The LAN local-share dialog is hidden on
  the web, where it cannot work.

### Fixed

- Web file processing end to end. This Flutter SDK no longer ships the web
  virtual filesystem — every `dart:io` file operation throws in the browser —
  so picked files are now kept in memory and fed to the processor as bytes
  under synthetic paths. Picking, previews, processing, saving (as download),
  camera capture, and config export/import all work on the web now.
- Web processing pipeline. The web engine of this SDK has no isolates at all
  (`Isolate.spawn`, `ReceivePort` and `TransferableTypedData` all throw
  `UnsupportedError` in the browser), which made every processing run fail
  with "Unsupported file or processing failed." The image and PDF pipelines
  now run on the main isolate on the web (same code, same message protocol);
  native platforms still use spawned isolates with zero-copy transfers. The
  progress UI is kept alive by yielding to the event loop between pipeline
  steps, though heavy steps still block the UI thread on the web.
- Log file download on the web: the log export is now handed to the browser
  as a download (the web has no documents directory to write to).

## 1.8.1

### Added

- In-app language selector in settings: System default, English, Français,
  Deutsch, Español, Italiano. The choice is persisted across launches; the
  default follows the device locale.
- Advanced expert mode with reorganized processing profiles.
- PNG support for watermarked output; reorganized icons and menu.
- HTTPS file transfer: streaming download, network choice, version log on
  the sender.
- Processing modal now shows the output filename and all options applied to
  the rendered image.
- More unit tests (streaming, encryption, steganography).

### Changed

- Signature verification is tri-state (`valid` / `invalid` / `error`): only a
  cryptographically valid signature counts as integrity-proven; a well-formed
  signature that fails is reported as tampering, and corrupt input is
  reported as an error with no cryptographic conclusion.
- File type detection fails closed: an unreadable file throws
  `WatermarkError(fileCorrupted)` instead of silently trusting the file
  extension.
- Android build: removed dead `DART_DEFINES` blocks from `build.gradle.kts`
  (never executed on current Flutter; `versionCode` comes from
  `--build-number`), and the build script no longer passes the no-op
  `--dart-define=VERSION_CODE`.
- `includeTimestamp` semantics documented: the visible watermark always
  carries a date/time stamp; the flag only gates the timestamp in the output
  filename.
- Pubspec description updated; analyzer now excludes platform build
  directories.

### Fixed

- Result cache: `forcePng` was missing from the cache key, so a cache hit
  could return the wrong encoding; it is now part of the key.
- Result cache: the signing identity is now part of the cache key (public
  key), and the cache is cleared when the identity is reset — a cached
  result can no longer carry a stale identity's signature.
- Windows build: silenced MSVC experimental coroutine deprecation warning.
- French translation accent in "Stéganographie".
- Transparency of colored icons and other color handling issues.
- ZIP password check.
- Missing settings (directory selection).
- Wrong information in the privacy policy.
- Android build failure when OpenSSL is not installed.
- Lint and build issues; removed print statements from production code.

### Housekeeping

- `android/app/build/` added to `.gitignore`; removed throwaway root files
  (analysis outputs, `test.cpp`, local clang shim).
- Added agent guides (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) and
  `RELEASE_NOTES_v1.8.0.md`.
