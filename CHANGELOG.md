# Changelog

All notable changes to SecureMark are documented in this file.

## 2.2.0

### Added

- **Per-profile ZIP default**: the "ZIP All Files" option is now enabled by
  default only for the Identity and Integrity profiles (both sign documents,
  which requires ZIP output). It is off by default for every other profile
  (Share Document, Online Image, QR Code, P1, P2).

### Changed

- **Apply button**: the floating button now shows a short "Apply" label
  (instead of "Apply SecureMark") and is lifted above the author footer so it
  no longer covers "Antoine Giniès vX.X.X" at the bottom of the screen.

### Fixed

- **Android release build**: disabled R8 minification for release builds.
  AGP 9 (from the 2.1.1 toolchain upgrade) ran R8 by default, which obfuscated
  `kotlin.coroutines.Continuation` and broke Pigeon dispatch for
  `shared_preferences`, crashing the app on startup in release.
- **Web privacy badge**: the "Confidentialité" link at the end of the badge is
  now shown in parentheses.

## 2.1.1

### Added

- **Web privacy badge**: the web top bar now shows a shield badge reassuring
  users that nothing is stored on a server and all processing happens in the
  browser, with a link to the confidentiality page. Localized in all 5
  languages.

### Changed

- **Android build**: upgraded to the canonical Flutter 3.47.6 toolchain —
  Gradle 8.14.0 → 9.3.1, Kotlin 2.2.20 → 2.4.0, AGP 8.11.1 → 9.1.0 — to clear
  the "support will soon be dropped" warnings. The app module now relies on
  the Flutter plugin's built-in Kotlin and uses the modern
  `kotlin { compilerOptions }` block instead of the deprecated
  `kotlinOptions`.
- **Apply button**: the floating "Apply SecureMark" button now greys out
  (disabled) until it can actually run — no files selected, an image watermark
  without an image loaded, or a run in progress.

### Removed

- **UI**: the particle/icon burst animation on the profile and color-picker
  tiles. The press-down "click" effect is kept; only the burst is gone.

## 2.1.0

### Added

- **Web identity & digital signing**: Device identity and the Digital Integrity
  Signature are now available in the browser. Users can set their name, view
  their personal public key, and sign documents on web — key material stays
  on-device via secure storage and signing runs in the WASM isolate.

### Changed

- **Identity watermark**: When signing, the device identity (name) is drawn as
  a subtle visible watermark in a random color, so a signed document carries an
  apparent, hard-to-strip mark in addition to the cryptographic signature.
- **Identity profile**: the Identity (`secureIdentity`) profile now uses a
  transparency of 75 for that watermark (less visible than the Image profile's
  50) instead of being fully invisible.

## 2.0.0

### Changed

- UX: the buried "Advanced Expert" gate is gone. Steganography, robust
  steganography, device identity and local network share are now available to
  everyone. The eight icon-only app-bar buttons are replaced by
  "Apply SecureMark" + a labeled "More options" overflow menu (Font/Image
  configuration, QR Code Watermark, My Device Identity, Local Network Share,
  Steganography, Analyze file), with Expert Options pinned top-right.
- Profiles: the "Doc" profile no longer enables the visible watermark or
  steganography — it produces a clean document (AI cloaking + anti-AI only).
- Profiles: the "Identity" profile now enables the Ed25519 digital integrity
  signature (with the required ZIP output) and no longer enables steganography
  or the visible watermark.
- Profiles: the P1/P2 custom profiles use a "tune" icon (custom configuration)
  instead of a person.

### Fixed

- Overflow of the French "Stéganographie (signature invisible)" label in the
  overflow menu; menu labels are now ellipsized in every language.
- Hardcoded English strings ("Hide File", "Network Interface", "QR Scanning
  not yet supported") are now localized in all 5 languages.

### Removed

- The "Advanced Expert" toggle and its now-dead strings (onboarding slide,
  gating hints).

## 1.9.0

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
- `docs/apache-vhost.example.conf`: ready-to-adapt Apache virtual host
  example for the web deployment (TLS with Let's Encrypt fullchain,
  HTTP→HTTPS redirect, wasm/mjs MIME types, bundle compression,
  HSTS, SELinux notes).
- Web build is now documented and scriptable: `./build_and_verify.sh
  build_web` builds both bundles (JS + WASM) into `build/web/` and
  packages `secure-mark-web.zip` like the other platforms; `all` and
  `collect_artifacts` include it, and the README has a Web section.
- Web legal pages: the footer now offers « Mentions légales » and
  « Confidentialité » dialogs (web only, French — the French version is the
  official one for French hosting). The privacy text documents the actual
  web behavior: 100% client-side processing, no server-side file storage,
  2-minute in-memory retention, localStorage preferences, no cookies, no
  analytics.

### Security

- File prefix can no longer escape the output directory. The prefix is a
  user-controlled string (settings field, imported config zip, saved
  profile) that was concatenated straight into the output path: a value
  like `../../evil/` could make the app write its output outside the
  source directory. It is now sanitized (path separators, drive colons,
  null and control characters stripped) both in the settings field and at
  the single choke point `WatermarkUtils.outputPath`, so every origin is
  covered. The ZIP password was audited and needed no change: it is only
  ever passed as an API parameter to the pure-Dart `archive` package,
  never to a shell, path, or command line.

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
