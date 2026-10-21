# SecureMark — Feature Review & Roadmap Proposal

> Status: **Proposal only — no code has been changed.**
>
> Scope: review of `lib/` (≈19.6k lines of Dart), `test/` (77 passing tests),
> platform manifests, CI, and the public processing API. Every claim below was
> verified against the working tree, and the robustness/steganography claims
> were measured with throwaway probe programs outside the repo.
>
> Companion document: [`refactoring_proposal.md`](refactoring_proposal.md)
> (Proposal A implemented, Proposal B still open).

---

## 1. Health snapshot (verified)

| Check | Result |
|---|---|
| `flutter analyze` | clean (0 issues) |
| `flutter test` | 77 pass — `AGENTS.md`/`GEMINI.md` still say "32 tests" (doc drift) |
| Test stability | `test/widget_test.dart` failed to *load* once in a full parallel run, then passed standalone and on 2 re-runs (flake) |
| DCT "robust" watermark | survives JPEG q80+; **fails q75/q60, any resize (even 95%), 5% crop, blur+q85** |
| LSB steganography | destroyed by **any** JPEG re-encode (measured at q100/95/90/85); UI does not auto-force PNG |
| WebP output | `WatermarkUtils.encodeImageInOriginalFormat` returns **PNG bytes** for `.webp` → mislabeled container, although `image` 4.10 ships a real `encodeWebP` |
| HEIC/HEIF | pickable and passes validation, but `image` 4.10 has **no HEIF decoder** → guaranteed decode failure |
| `securemark://verify` deep links | generated and QR-encoded (`lib/steganography/forensic_utils.dart:66`) but the scheme is **not registered** in `AndroidManifest.xml` / `Info.plist` → dead links |
| Result cache | FIFO, not LRU (`_addToCache` evicts `keys.first`; hits do not reorder) and byte-unbounded (10 × up to ~200 MB) |
| Batch processing | strictly sequential (`lib/pages/parts/state.processing.dart:267`) |
| Android manifest | declares `com.pravera.flutter_foreground_task.service.ForegroundTaskService` + `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC`, but the plugin is in **neither** `pubspec.yaml` nor `pubspec.lock` |
| Accessibility | **0** `Semantics` widgets in `lib/`; 5 tooltip/semanticLabel uses across ~14k lines of UI |
| Localization | 4+ hardcoded English strings in `lib/pages/parts/state.builders.dart` (1851, 2003, 2086, 2147); `scripts/check_translations.py` is not wired into CI or `build_and_verify.sh` |
| PDF "digital signature" | a custom `SecureMarkIntegrity:` string in PDF **Keywords** metadata (`lib/watermark_processor.dart:1892`) — invisible to Acrobat; Syncfusion's real `PdfSignature` / `PdfCertificate` are already vendored and unused |

### 1.1 Measured robustness evidence

Current `DctHandler` (1024-bit sequential payload, one bit per 8×8 block,
mid-frequency coefficient 36, ±20 quantization, no redundancy, no ECC, no
geometric sync):

| Attack | Result |
|---|---|
| PNG round-trip | OK |
| JPEG q95 / q90 / q85 / q80 | OK |
| JPEG q75 / q60 | **FAIL** |
| Resize 95% / 90% / 75% / 50% (+q85) | **FAIL** |
| Crop 5% | **FAIL** |
| Gaussian blur r=1 + JPEG q85 | **FAIL** |
| WebP lossy | OK |

A ~150-line throwaway prototype (32-bit payload, 32×32 tile redundancy,
4 blocks per tile, majority vote) survived **JPEG q40, blur + q75, WebP q70**,
and still failed resize/crop — confirming that redundancy buys compression
robustness cheaply, while geometric attacks need real synchronization work.

LSB text signature: **fails at every JPEG quality including q100**, survives
PNG round-trip. The pipeline only forces a lossless container when
`forcePng || digitallySign` (`lib/watermark_processor.dart:535`), so enabling
steganography on a JPEG input without ticking "Force PNG" silently loses the
payload.

---

## 2. P0 — high impact, contained effort, additive

### 2.1 Per-recipient fingerprinting + leak tracing ("traitor tracing")

- **Problem.** Every recipient receives a byte-identical file. When a document
  leaks, nothing attributes it to a recipient — the "high-security document
  distribution" promise stops at "this file is mine".
- **User benefit.** N personalized variants, each carrying an invisible
  recipient ID; the Analyzer maps a recovered copy back to
  *"distributed to X on {date}"*. This is the differentiating feature for the
  product's stated market.
- **Implementation.**
  - `lib/models/distribution.dart` — recipient + ledger entry models.
  - Recipients editor dialog (manual entry / CSV import).
  - "One variant per recipient" batch mode threading a `fingerprintId` into the
    existing DCT + LSB payload paths.
  - Hash-chained local ledger (JSON in the app directory, signed with the device
    identity key).
  - Analyzer panel: fingerprint → recipient lookup, with an "unknown
    fingerprint" state.
- **Estimated size.** ~900–1,400 hand-written lines (ledger ~250, UI ~350,
  processor plumbing ~150, analyzer ~200, tests ~200) plus ~25 l10n keys × 5
  `.arb` files (≈125 lines) and ~600 generated localization lines.
- **API / compatibility.**
  - New `processFile` parameters are optional ⇒ source-compatible.
  - **`WatermarkCacheInput` is a public record typedef; adding a field is
    source-breaking** for any external constructor. Only 2 internal call sites
    exist and `publish_to: none`, so the blast radius is the repo itself.
  - Payload format must stay version-compatible: keep the `SR` magic and add a
    versioned fingerprint field so previously distributed outputs still analyze.

### 2.2 Robust watermark v2 + attack benchmark harness ("Robustness Lab")

- **Problem.** The README claims the DCT mark "survives image transformations
  (compression, resizing, etc.)"; measured, it dies at JPEG q75 and at any
  geometric change. There is no harness, so regressions are invisible and the
  public claim is unbacked.
- **User benefit.** A survival matrix (JPEG q40–95, WebP, resize, crop, blur,
  screenshot / print-scan simulation) shown in-app and asserted in CI — turns a
  marketing claim into evidence and keeps it true.
- **Implementation.**
  - `lib/steganography/robust_codec.dart` — redundancy + majority vote, optional
    Reed–Solomon, versioned header.
  - `lib/analysis/attack_suite.dart` — pure Dart attack battery, run in an
    isolate with progress + cancellation.
  - Report panel reusing the existing dialog patterns.
  - `test/robustness/` threshold tests wired into `quality_checks`.
  - Keep `DctHandler.extractRobustSignature` as the v1 fallback reader.
- **Estimated size.** ~500–800 lines (codec ~250, harness ~200, UI ~150,
  tests ~150).
- **API / compatibility.** Additive. **Dual-read is mandatory** — without a v1
  fallback every previously distributed document stops verifying. CPU cost must
  stay bounded (isolate, progress, cancel).

### 2.3 Lossless-container guard + true WebP output

- **Problem.** Enabling LSB steganography on a JPEG silently destroys the
  payload (verified at q100). `.webp` outputs are PNG bytes written into a
  `.webp`-named file.
- **User benefit.** No silent data loss, no mislabeled containers, smaller files
  when WebP is actually wanted.
- **Implementation.** Auto-select a lossless container when `useSteganography`
  or hidden-file embedding is on (or block with an explanatory dialog); switch
  the `.webp` branch of `encodeImageInOriginalFormat` to
  `img.encodeWebP(lossless: stegoOn)`.
- **Estimated size.** ~120–250 lines.
- **API / compatibility.** No API break, but **output bytes and/or extension
  change** for WebP runs and stego-on-JPEG runs ⇒ CHANGELOG entry required;
  result-cache keys shift (expected and harmless).

### 2.4 Offline verifier + working `securemark://` links

- **Problem.** Verification requires the app, and the embedded deep link cannot
  even be opened by the OS because no platform registers the scheme.
- **User benefit.** Any recipient verifies a document with a camera + browser
  and no install; the ZIP ships a self-contained `verify.html` carrying the
  hashes, public key and signature. This closes the trust story end to end.
- **Implementation.**
  - Register the scheme: Android `intent-filter` (VIEW + BROWSABLE), iOS
    `CFBundleURLTypes`, desktop protocol handler; route incoming links into the
    existing verification path.
  - Generate a static HTML verifier using WebCrypto Ed25519 (Chrome 137+,
    Safari 17, Firefox 129) with a bundled JS fallback for older browsers.
- **Estimated size.** ~450–700 lines (HTML/JS asset ~200, generator ~150,
  scheme registration + link handling ~200, l10n ~80, tests ~80).
- **API / compatibility.** None broken. New intent filters must not collide with
  the existing `ACTION_SEND` filters; the HTML asset must be added to
  `pubspec.yaml`.

---

## 3. P1 — strong value, moderate effort or risk

### 3.1 Real PDF digital signature (PAdES/CMS) via Syncfusion `PdfSignature`

- **Problem.** The current signature is a Keywords string that no standard PDF
  reader validates.
- **Benefit.** Signatures that open in Adobe Acrobat as "signed by …", plus
  certification permissions — table stakes for legal/compliance distribution.
- **Implementation.** Generate or import a PKCS#12 (openssl on desktop, pure
  Dart ASN.1 via pointycastle elsewhere), add a `PdfSignatureField` with a
  visible appearance, and sign **last**.
- **Estimated size.** ~700–1,200 lines (PFX generation 300–500, signing
  integration ~200, certificate UI ~250, tests ~150).
- **Compatibility risk.** The pipeline re-saves the document after hashing
  (`lib/watermark_processor.dart:1892`) — that ordering **invalidates** a CMS
  signature and must change. Keep reading the legacy Keywords signature.
  Mobile/web PFX generation is the main technical risk. Syncfusion license
  terms apply (already a dependency).

### 3.2 Signed, persistent audit trail + "Certificate of Processing"

- **Problem.** Logs are 100 in-memory lines, lost on restart — no evidence for
  compliance.
- **Benefit.** Tamper-evident, hash-chained record of every run (input hash,
  settings hash, output hash, identity, timestamp), exportable and verifiable,
  optionally as a signed PDF certificate.
- **Estimated size.** ~500–750 lines.
- **Compatibility.** Additive. Web has no filesystem ⇒ in-memory + download.
  Store hashes only (privacy promise).

### 3.3 Identity lifecycle: encrypted backup/restore, rotation, revocation

- **Problem.** Losing the device loses the identity forever; a compromised key
  cannot be revoked.
- **Benefit.** Passphrase-encrypted recovery kit (file or split QR), key
  rotation with a signed successor statement, revocation statements honored by
  the Analyzer.
- **Estimated size.** ~600–900 lines.
- **Compatibility.** Must not weaken "the private key never leaves the device":
  explicit, user-initiated, encrypted. `_isConfigBackupKey` must keep blocking
  `device_private_key`; imports must fire `onIdentityChanged` (cache
  invalidation is already wired).

### 3.4 HEIC/HEIF: real decoding or honest rejection

- **Problem.** HEIC is advertised and pickable but undecodable ⇒ a confusing
  failure on the most common iPhone format.
- **Benefit.** iPhone photos work, or users get an actionable message instead of
  a decode trace.
- **Estimated size.** ~250–450 lines (platform channel to ImageIO / Android
  HEIF, or a compress plugin); ~40 lines for honest rejection only.
- **Compatibility.** New per-platform code; keep the Samsung TIFF-wrapped-JPEG
  fallback intact; web unaffected.

### 3.5 Parallel batch pool + memory-bounded cache (actual LRU)

- **Problem.** Sequential batch processing; a FIFO cache holding up to ~2 GB of
  image bytes.
- **Benefit.** Near-linear speedup on desktop batches; no OOM on 50 MP inputs.
- **Estimated size.** ~300–450 lines.
- **Compatibility.** Bound the pool by image size / available RAM; preserve
  per-file cancellation and progress accounting.

---

## 4. P2 — worthwhile, cheaper or narrower

| # | Feature | Est. LOC | Notes / risk |
|---|---|---|---|
| 10 | Watch folder + unattended desktop automation | 350–550 | desktop-only; needs explicit enable + profile snapshot to avoid runaway jobs |
| 11 | Privacy report (metadata / GPS diff) | 300–450 | also fixes a real leak: `preserveMetadata` clones the full EXIF **including the thumbnail**, which can retain the unwatermarked original, plus GPS |
| 12 | Stego capacity meter + pre-flight checks | 150–250 | removes the late "too large to hide" failure after a long run |
| 13 | Web parity: enable the Analyzer on web | 200–350 | `analyzeFileAsync(bytes, name)` is already byte-based; mostly ungating + a web save path |
| 14 | App lock (biometric/PIN) + secure erase of intermediates | 400–600 | adds `local_auth`; platform config; must be mockable in tests; overwrite-before-delete is best-effort on flash — document honestly |
| 15 | l10n + accessibility pass | 300–500 (+~1,500 generated) | 0 `Semantics`, 4+ hardcoded strings, wire `check_translations.py` into CI |
| 16 | Repo hygiene bundle | ~100 | remove or implement the dead `flutter_foreground_task` service + `FOREGROUND_SERVICE*` permissions (Play Console exposure); fix the "32 tests" doc drift; stabilize the flaky `widget_test.dart` load |

---

## 5. P3 — stretch (named, not committed)

- **C2PA / Content Credentials.** Industry-standard provenance, but no Dart
  library exists ⇒ hand-rolled JUMBF + COSE or `c2pa-rs` over FFI. ~2,000+
  lines, heavy native binaries, poor web/WASM coverage. Recommended first step:
  a scoped **signed XMP provenance manifest** (~300 lines).
- **Animated GIF / video.** GIF is feasible with `image` frames (~400–600
  lines); video needs ffmpeg (binary size + licensing) ⇒ defer.
- **Office documents (DOCX/XLSX/PPTX).** OOXML header injection via the existing
  `archive` dependency, ~700–1,200 lines, real fidelity risk.
- **Headless CLI / SDK extraction.** Blocked by `dart:ui` `TextPainter` in the
  font-rendering path — needs a renderer seam first (~800–1,200 lines of
  refactor).

---

## 6. Sizing and risk summary

- **P0 + P1 total: ~4,000–6,000 hand-written lines**, plus ~2,000–3,000
  generated localization lines.
- **One source-breaking API surface:** `WatermarkCacheInput` (public record
  typedef) — adding a field breaks any external constructor. No external
  consumers exist (`publish_to: none`).
- **Two behavior-changing output decisions:** WebP container correctness and
  lossless forcing when steganography is on. Both need CHANGELOG coverage.
- **One hard ordering constraint:** a real CMS/PAdES PDF signature must be the
  last write to the document.
- **One backward-compatibility invariant:** any new invisible payload must keep
  a v1 reader, or every previously distributed document stops verifying.
- **Localization cost rule of thumb:** each new user-facing string touches 5
  `.arb` files plus regenerated `lib/l10n/app_localizations*.dart` — budget
  ~24 generated lines per key.

## 7. Suggested sequencing

1. **P2 #16 hygiene bundle** first (dead manifest service, doc drift, test
   flake) — cheap, unblocks clean CI signal for everything else.
2. **P0 #3 lossless/WebP guard** — smallest diff, removes silent data loss.
3. **P0 #2 robustness harness** — establishes the measurement baseline before
   touching the codec.
4. **P0 #1 recipient fingerprinting** — the headline feature, built on the
   hardened codec.
5. **P0 #4 offline verifier + scheme registration** — makes the fingerprint and
   signature story usable by recipients.
6. **P1** items in the order listed, with #5 (PAdES) scheduled only after a
   spike proves pure-Dart PFX generation on mobile.

Each step must leave `./build_and_verify.sh quality_checks` green.
