# Changelog

All notable changes to SecureMark are documented in this file.

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
