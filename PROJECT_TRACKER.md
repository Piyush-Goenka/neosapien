# NeoSapien Project Tracker

## 1. Project Snapshot
- Deadline: 2026-04-20 08:00 PM (submission day)
- Goal: Ship a production-grade cross-device file sharing app that works on a real iPhone and a real/emulated Android device over the public internet.
- Platforms: Flutter app with Android + iOS parity. Devices available: real iPhone + Android emulator on Mac.
- Primary bonus (weighted heavily in rubric): Pigeon-based background transfer on Android and iOS.
- Secondary bonus: native picker (SAF / UIDocumentPicker), native save (MediaStore / PHPhotoLibrary), native share sheet.
- Current phase: M2 → M3 transition — core happy path is code-complete; hardening, closed-app discovery, native bonuses, and submission assets are the remaining work.
- Overall status: [/]
- Current focus: Track A (P0) — partial-failure isolation, SHA-256 integrity, permission handling, low-storage preflight, FCM closed-app discovery via Cloud Function, security rules, and submission package.
- Next milestone: M3 Resilience And Starred Cases.
- Latest blocker: Blaze billing must be enabled on the Firebase project before the FCM Cloud Function can be deployed; real-device validation still pending.
- Demo readiness: [ ] Not ready
- Submission readiness: [ ] Not ready

## 1A. Progress Summary

### Done So Far
- Flutter app scaffolded with Android + iOS targets and clean feature-first layering (`app`, `core`, `features`, `shared`).
- Production app shell with GoRouter, Material 3 theme, bottom navigation, Riverpod DI, and disposal-aware providers.
- Typed domain contracts: identity, recipient value object with unambiguous alphabet, transfer batch/file entities, 15-state status machine, typed failure codes, and network policy enum.
- Hybrid identity repository: local secure-storage fallback plus Firebase anonymous auth and Firestore-backed short-code reservation with transactional retry.
- Recipient lookup flow with malformed-code rejection, self-send block, and clear missing-recipient messaging (Firestore-backed).
- Sender-side file picking via `file_picker`, MIME inference, preflight validation (per-file, per-batch, file-count ceilings) without loading bytes into memory.
- Firestore-backed transfer control plane: create, watch, accept, reject, cancel with role-scoped transactions in `firestore_transfer_remote_data_source.dart`.
- Firebase Storage data plane: streaming upload and download with shared per-file + aggregate progress, progress-sync heuristic (256KB delta or 350ms), cancel support, and failure-code mapping.
- Recipient-side save into per-batch app-documents directory with deterministic filename-conflict rename and persisted saved-path history surviving relaunch.
- Pigeon contract scaffolded for host/flutter APIs covering start, pause, resume, cancel, query, and progress/state events.
- Project hygiene: stricter analyzer, `.env.example`, README baseline, updated `.gitignore`, runtime Firebase configuration via `--dart-define` (no secrets in repo).
- Test suite covers short-code generator, draft validator, recipient lookup controller, draft composer controller, batch action controller, and received-file store.
- Foundation gates green: `flutter analyze` clean, `flutter test` passing on 2026-04-19.

### Left To Do (to earn the grade)
- **Firebase ops**: enable Blaze, supply real project values, deploy Firestore + Storage security rules, deploy Cloud Function for FCM push, and capture required composite indexes for the `transfers` queries.
- **Track A (P0) client hardening**:
  - Partial failure isolation: one failed file must not kill the batch; per-file retry.
  - SHA-256 integrity: sender streams hash into transfer doc, receiver verifies on save.
  - Permission handling: `permission_handler` for notifications, photo-add, Android 13+ media perms; actionable denial UX, no crashes.
  - Low-storage preflight: refuse accept/download when free < total × 1.1.
  - Metered-connection enforcement: `connectivity_plus` check against `NetworkPolicy` before upload.
  - Process-death recovery: stale in-flight batches on boot → fail-cleanly + recoverable retry.
  - Closed-app discovery: FCM token persistence on `users/{uid}`, local notification on receive, deep link into `/inbox?batch=<id>`.
  - Firestore + Storage security rules committed in `firebase/` and deployed.
- **Track B (Bonus)** — only if A is green:
  - Generate Pigeon bridge; commit generated Dart/Kotlin/Swift files.
  - Android background transfer via Foreground Service + WorkManager reconciler (Bonus B).
  - iOS background transfer via `URLSession(configuration: .background)` (Bonus C).
  - Native pickers: Android `ACTION_OPEN_DOCUMENT`, iOS `UIDocumentPickerViewController` (Bonus D).
  - Native save: Android `MediaStore.Downloads`, iOS `PHPhotoLibrary` (Bonus E).
- **Submission**:
  - README rewrite: architecture ASCII, transport choice rationale, ★ coverage table, known limitations, AI disclosure, device matrix.
  - Signed debug APK built + tested on clean Android.
  - iOS build path verified on real iPhone (Xcode run instructions if no Apple Developer enrollment).
  - Walkthrough video (5–8 min) with both devices visible, code tour, and two failure modes.
  - Drive folder assembled: APK, source (GitHub link), README, `.env.example`, video.

## 1B. Remaining Work In Priority Order

Today-only plan, deadline 2026-04-20 20:00.

### Track A — Must ship (P0)

- [ ] **A1. Firebase ops**: enable Blaze on the project; populate `--dart-define` values for Android + iOS; author and deploy `firebase/firestore.rules` + `firebase/storage.rules` + any composite indexes; validate on one device.
- [ ] **A2. Partial-failure isolation** in [firebase_storage_transfer_engine.dart](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart): replace fail-fast loop with per-file try/catch; finalize batch as `completed` if any succeed, `failed` otherwise; add `retryFile(batchId, fileId)` + "retry only failed files" on `TransferBatchActionController`.
- [ ] **A3. SHA-256 integrity**: sender hashes while reading, writes `checksumSha256` to transfer file doc; receiver hashes while writing, marks `corrupted` on mismatch and deletes partial file. Use `package:crypto`'s `sha256.bind(stream)`.
- [ ] **A4. Permission handling**: add `permission_handler`; wrap notification + photos-add + Android 13 media permissions behind a `PermissionGateway` service (domain interface + platform impl). Every denial shows actionable copy with "Open settings" CTA.
- [ ] **A5. Low-storage preflight**: add `disk_space_plus` (or platform channel via Pigeon) to check free space before `acceptBatch` and before each download; fail with typed `TransferFailureCode.lowStorage`.
- [ ] **A6. Metered-connection enforcement**: add `connectivity_plus`; if `ConnectivityResult.mobile` and `networkPolicy != allowMetered`, block upload start and show warning.
- [ ] **A7. Process-death recovery**: on boot, scan batches with status `uploading`/`downloading` and `updatedAt > 60s` ago + `lastUpdatedBy == self`; mark `failed` with `isRecoverable: true`; expose "resume" (restart-from-zero for now, note limitation).
- [ ] **A8. FCM closed-app discovery** (Cloud Function, Option A):
  - Persist FCM token on `users/{uid}.fcmTokens[]` on login + token refresh.
  - Cloud Function `onTransferCreated` (Firestore trigger on `transfers/{id}` create) reads recipient tokens and sends data message with `batchId`.
  - Dart: local notification via `flutter_local_notifications`; notification tap → deep-link through GoRouter to `/inbox?batch=<id>`.
- [ ] **A9. Duplicate delivery dedupe**: on save, check `localPath` already recorded in `TransferDownloadLocalDataSource` for the `(batchId, fileId)` key; skip write if present. Also enforce idempotency on Cloud Function via message ID.
- [ ] **A10. README rewrite**: architecture ASCII, transport justification, full ★ coverage table with file references, known limitations, AI usage disclosure, device test matrix.
- [ ] **A11. Real-device run + walkthrough video + Drive package**: signed debug APK; iPhone build via Xcode; record 5–8 min video with both screens visible (onboarding, code exchange, transfer, Wi-Fi toggle, bad code, large file, app-kill-reopen, 60s code tour); assemble Drive folder.

### Track B — Bonus (only if A fully green)

Order chosen for highest rubric-per-hour given rubric weighting and device availability.

- [ ] **B1. Generate Pigeon bridge**: `dart run pigeon --input pigeons/native_transfer_bridge.dart`; commit generated files.
- [ ] **B2. Bonus B — Android background transfer**: Kotlin foreground service + WorkManager; Android Firebase Storage SDK (already supports app-death resume via `UploadTask#pause()` + `StorageReference#getActiveUploadTasks`) for the actual bytes; Pigeon `NativeTransferEngine` Dart adapter; override `transferEngineProvider` on Android via `defaultTargetPlatform`.
- [ ] **B3. Bonus C — iOS background transfer**: Swift `URLSession(configuration: .background)` + `URLSessionUploadTask` against signed Firebase Storage URL; reconcile via `application(_:handleEventsForBackgroundURLSession:)`; same Pigeon contract.
- [ ] **B4. Bonus D — native picker**: Kotlin `ACTION_OPEN_DOCUMENT` + Swift `UIDocumentPickerViewController` behind `TransferFileSelector` interface; keep `file_picker` as fallback via Strategy pattern.
- [ ] **B5. Bonus E — save to gallery**: Kotlin `MediaStore.Downloads` (API 29+) + Swift `PHPhotoLibrary.shared().performChanges`; uses permissions already wired in A4.
- [-] Bonus F (Nearby fallback) — explicitly deferred.

## 2. Status Legend
- [ ] Not started
- [/] In progress
- [x] Done
- [!] Blocked
- [-] Deferred

## 3. Non-Negotiable Success Criteria
- [ ] Android -> iPhone transfer works on real devices
  - Done when: Media batch is sent by short code, received without refresh, accepted, downloaded, verified, and saved.
  - Evidence:
- [ ] iPhone -> Android transfer works on real devices
  - Done when: Reverse direction passes with the same status visibility and reliability.
  - Evidence:
- [ ] Real-time progress is visible on both sender and recipient
  - Done when: Per-file and aggregate progress update within a couple of seconds while both apps are open.
  - Evidence:
- [ ] All starred edge cases are implemented, not just documented
  - Done when: Every starred item in Section 3 of the brief is tested and marked complete below.
  - Evidence:
- [ ] README and walkthrough are honest and reviewer-ready
  - Done when: Setup, architecture, tradeoffs, handled/unhandled cases, AI usage, and failure demos are fully documented.
  - Evidence:

## 3A. Architectural Principles (industry-standard patterns applied)

These are already in the codebase or baked into the plan — calling them out so reviewers see the rationale.

- **Clean / Hexagonal layering** per feature: `domain` (entities, value objects, repository interfaces, services) → `data` (data sources, repository impls) → `application` (controllers, providers) → `presentation` (screens, widgets). No inward dependencies violated.
- **Repository pattern** with data-source split: Firestore/Storage/SecureStorage calls live behind data-source classes; repositories orchestrate; controllers depend only on domain interfaces.
- **Composite / hybrid repository** (fallback strategy): `HybridIdentityRepository` and `HybridTransferRepository` degrade to local-only when Firebase is unreachable.
- **Strategy pattern** for transport: `TransferEngine` interface with `FirebaseStorageTransferEngine` today and `NativeBackgroundTransferEngine` (Pigeon-backed) for Android/iOS when B2/B3 ship. Selected by Riverpod override per platform.
- **State machine** via `TransferStatus` enum with explicit 15 states; no stringly-typed statuses.
- **Value objects** for `RecipientCode`, `UserIdentity`, planned `FileChecksum` — invariants enforced by construction.
- **Typed failures**: sealed `AppException` hierarchy + `TransferFailureCode` enum + `isRecoverable` flag. UI dispatches on failure code, not on string matching.
- **Observer via streams**: Firestore `.snapshots()` exposed as Riverpod `StreamProvider`; UI reacts without refresh.
- **Dependency injection via Riverpod**: explicit providers, scoped disposal, testable via `ProviderContainer(overrides: ...)`.
- **Platform-channel isolation via Pigeon**: typed contract on both sides, no manual `MethodChannel` strings, code-generated Dart/Kotlin/Swift bindings.
- **Idempotency**: `(batchId, fileId)` as natural dedupe key on receiver; FCM message ID dedupe on Cloud Function trigger.

## 4. Rubric Coverage

### 4.1 Core Requirements
- [x] Anonymous onboarding with local identity provisioning
  - Evidence: `LocalIdentityRepository` + `CurrentIdentityController` provision and persist a local identity via secure storage; surfaced in dashboard/profile; widget and unit tests passing.
- [/] Short-code identity generation and registration
  - Evidence: `HybridIdentityRepository` uses Firestore transactional reservation with up to 24 random retries; persists locally; pending live-project validation (A1).
- [/] Send one or more media files to a short code
  - Evidence: end-to-end draft → upload → accept → download → save flow implemented through `TransferDraftComposerController`, `HybridTransferRepository`, `FirebaseStorageTransferEngine`. Live device validation pending (A11).
- [/] Works across distance / internet relay
  - Evidence: identity, lookup, control plane, and data plane all traverse Firebase (Auth + Firestore + Storage) over TLS. Pending live config + device verification (A1, A11).
- [ ] Real-device proof path
  - Evidence:
- [/] Real-time progress and final success/failure states
  - Evidence: outgoing uploads and incoming downloads write aggregate + per-file progress to Firestore; both send and inbox screens render from the same `TransferProgressSummary` widget. Pending device verification.

### 4.2 Starred Edge Cases
- [/] Short-code collisions handled
  - Evidence: `IdentityRegistryRemoteDataSource.reserveIdentity` uses Firestore transactions + retries; pending live-project verification (A1).
- [/] Invalid recipient code fails fast with clear UI
  - Evidence: `RecipientLookupController` rejects malformed codes synchronously and surfaces "No device is registered under that code yet" on Firestore miss; covered by `recipient_lookup_controller_test.dart`.
- [/] Recipient offline behavior implemented
  - Evidence: Firestore records persist and surface when recipient next opens the app. TTL enforcement and push-based wake land with A8 (Cloud Function).
- [/] Network drop mid-transfer handled
  - Evidence: failures mapped to recoverable state; retry restarts from zero today. True chunk-offset resume lands with native background engines (B2/B3). Will be documented honestly in README (A10).
- [/] Large files handled without OOM
  - Evidence: `TransferDraftValidator` ceilings; `FilePicker.pickFiles(withData: false)` keeps selection metadata-only; `FirebaseStorageTransferEngine.putFile` streams from disk. Pending 500MB on-device run (A11).
- [/] Multiple files at once with partial failure isolation
  - Evidence: per-file progress + metadata + retry surfaces exist; fail-fast loop will be replaced in A2 so one failed file no longer stops the batch.
- [ ] Permission denial degrades gracefully
  - Evidence: Landing in A4 via `PermissionGateway` + `permission_handler`.
- [ ] Incoming transfer while app is closed is discoverable
  - Evidence: Landing in A8 via Cloud Function + `flutter_local_notifications` + GoRouter deep link.
- [/] Transport encryption enforced
  - Evidence: Firebase Auth/Firestore/Storage are TLS by default. README documentation lands in A10.

### 4.3 Important Non-Starred Cases
- [x] Ambiguous characters removed from code alphabet
  - Evidence: `RecipientCodeCodec.alphabet` excludes `O/0/I/l/1`; `short_code_generator_test.dart` verifies.
- [x] Self-send policy implemented
  - Evidence: `RecipientLookupController.resolveRecipient` blocks self-send with explicit UX.
- [ ] Duplicate delivery dedupes by transfer ID
  - Evidence: Landing in A9 via `(batchId, fileId)` lookup on save + FCM message-id dedupe.
- [/] Metered connection warning added
  - Evidence: `NetworkPolicy` modeled and selectable; enforcement lands in A6 with `connectivity_plus`.
- [/] Unusual MIME and zero-byte files do not crash
  - Evidence: `MimeTypeGuesser` + `transfer_draft_validator_test.dart` cover extensions and zero-byte; transport coverage lands with device tests (A11).
- [x] Filename conflict policy implemented
  - Evidence: `ReceivedTransferFileStore.createTargetFile` appends deterministic suffixes; covered by `received_transfer_file_store_test.dart`.
- [ ] Corruption detection via hash verification
  - Evidence: Landing in A3 (SHA-256 streaming hash on sender + receiver).
- [ ] Low storage preflight checks implemented
  - Evidence: Landing in A5.
- [ ] Background / process death recovery implemented
  - Evidence: Landing in A7; deeper recovery with native engines in B2/B3.
- [ ] Network transitions and airplane mode handled
  - Evidence: Partial from A6 (`connectivity_plus` subscription) + A7 (resume on boot); documented openly in README.

### 4.4 Bonus Targets
- [/] Bonus A: Pigeon bridge defined and integrated
  - Evidence: `pigeons/native_transfer_bridge.dart` contract present; generation + native wiring land in B1.
- [ ] Bonus B: Android background transfer (WorkManager + Foreground Service)
  - Evidence: Plan in B2. Depends on B1.
- [ ] Bonus C: iOS background transfer (`URLSession` background config)
  - Evidence: Plan in B3. Depends on B1.
- [ ] Bonus D: Native picker integration (SAF + UIDocumentPicker)
  - Evidence: Plan in B4.
- [ ] Bonus E: Native save-to-gallery/downloads (MediaStore + PHPhotoLibrary)
  - Evidence: Plan in B5.
- [-] Bonus F: Nearby fallback transport
  - Evidence: Explicitly deferred; noted in README.

## 5. Milestones

- [x] M0 Foundation
  - Evidence: Flutter shell, env management, lint/test, Firebase bootstrap, architecture boundaries; `flutter analyze` + `flutter test` green on 2026-04-19.

- [/] M1 Identity And Addressing
  - Evidence: Hybrid identity, Firestore reservation, recipient lookup, profile UI, invalid-code handling implemented. Gate: live-project verification (A1).

- [/] M2 Core Transfer Happy Path
  - Evidence: selection, validation, Firestore-backed transfer records, inbox discovery, accept/reject, Storage upload + download + save + history, shared progress implemented and green in tests. Gate: device-level verification (A11).

- [ ] M3 Resilience And Starred Cases
  - Evidence: completes with A2–A9. All ★ boxes must flip green.

- [ ] M4 Native Background Transfer Bonus
  - Evidence: completes with B1–B3.

- [ ] M5 Cross-Platform Hardening
  - Evidence: device matrix + OEM/permission polish (partly covered by A4/A7; finalized with B2/B3).

- [ ] M6 Submission Assets
  - Evidence: A10 (README) + A11 (APK + iOS + video + Drive).

## 6. Workstream Tracker

### 6.1 Architecture And Foundation
- [x] Feature modules + layer boundaries — `lib/app`, `lib/core`, `lib/features`, `lib/shared`.
- [x] Typed error model + transfer state machine — `core/errors/app_exception.dart`, `features/transfers/domain/entities/*`.
- [x] Strict analyzer + test config — `analysis_options.yaml`, green on 2026-04-19.
- [ ] Pattern documentation — called out in Section 3A; finalize in README (A10).

### 6.2 Backend And Relay
- [/] Firebase Auth, Firestore, Storage wired — providers live; rules + config pending.
- [/] Unique short-code reservation flow — Firestore transactional reservation; pending live verification.
- [ ] **FCM Cloud Function for closed-app discovery** — A8.
  - Cloud Function `functions/src/onTransferCreated.ts`: Firestore `onDocumentCreated` trigger → read `users/{recipientUid}.fcmTokens` → `admin.messaging().sendEachForMulticast` with data message.
  - Requires Blaze enabled.
- [ ] Firestore + Storage security rules — `firebase/firestore.rules` + `firebase/storage.rules`, deployed via `firebase deploy`.
- [-] Cloud Run resumable relay — deferred; Firebase Storage native resumable upload covers the requirement. Document in README.
- [ ] TTL + signed access — client already writes `expiresAt`; enforcement via scheduled Cloud Function (stretch, post-demo).

### 6.3 Flutter Transfer Experience
- [x] Onboarding / profile — dashboard + profile render identity and runtime config.
- [x] Recipient lookup + send composer — Firestore-backed with validation, self-send block, picker, policy selector.
- [/] Sender progress UI — per-file + aggregate rendering in place; add partial-failure visualization (A2).
- [x] Recipient inbox + accept/reject — live stream, action controller, shared progress.
- [/] Download progress + save + completed history — implemented; integrity check (A3), dedupe (A9), and low-storage (A5) still pending.
- [ ] Notification tap → deep link — A8 wires `go_router` deep link into `/inbox?batch=<id>`.

### 6.4 Android Native
- [ ] Pigeon Android host API — B1 generates the skeleton; B2 implements methods.
- [ ] WorkManager + Foreground Service — B2. Service type `dataSync`; notification channel; OkHttp / Firebase Storage SDK for bytes; Firestore SDK for progress sync.
- [ ] Android permission UX — A4 (notifications + Android 13 media).
- [ ] Android notifications + deep links — A8 delivers FCM; native intent opens MainActivity with extras consumed by GoRouter.
- [ ] `MediaStore.Downloads` save — B5.
- [ ] `ACTION_OPEN_DOCUMENT` picker — B4.

### 6.5 iOS Native
- [ ] Pigeon iOS host API — B1 generates; B3 implements.
- [ ] Background `URLSession` — B3.
- [ ] iOS permission UX — A4 (`NSPhotoLibraryAddUsageDescription`, `NSUserNotificationsUsageDescription`).
- [ ] iOS notifications + deep links — A8 via APNs through FCM.
- [ ] `PHPhotoLibrary` save — B5.
- [ ] `UIDocumentPickerViewController` picker — B4.

### 6.6 Reliability And Edge Cases
- [ ] Disk-space checks — A5.
- [ ] Hash verification — A3.
- [/] Retry / cancel / backoff — cancel + retry implemented; exponential backoff + per-file retry land in A2.
- [ ] Persistence / reconciliation — A7 (boot-time stale scan); strengthened by B2/B3.
- [ ] Metered-connection enforcement — A6.
- [ ] Duplicate delivery dedupe — A9.

### 6.7 Docs, QA, And Submission
- [ ] Real-device test matrix — A11.
- [ ] README rewrite — A10.
- [ ] Walkthrough video — A11.
- [ ] Drive package — A11.

## 7. Device And Test Matrix
- Android emulator (Mac host): TBD — to be filled in A11.
- Android OS version: TBD.
- iPhone physical device: YES — owner-supplied.
- iOS version: TBD.
- Test date: 2026-04-20.
- Last successful Android -> iPhone run:
- Last successful iPhone -> Android run:
- Last successful background recovery run on Android:
- Last successful background recovery run on iPhone:
- Known platform-specific issues:

Brief explicitly allows "one physical + one emulator"; iPhone is the physical device, Android is the emulator. Document this choice honestly in README.

## 8. Risk Register
- Risk: Blaze billing not enabled in time to deploy Cloud Function for FCM.
  - Impact: ★ closed-app discovery box stays unchecked; rubric hit.
  - Mitigation: Enable Blaze before starting A8; if blocked, fall back to Option B (local notification on next open) and document honestly in README.
  - Owner: Piyush
  - Status: Open
- Risk: iPhone build path requires Apple Developer enrollment for TestFlight.
  - Impact: Submission cannot ship a TestFlight link.
  - Mitigation: Provide Xcode run instructions and unsigned build; brief explicitly accepts this.
  - Owner: Piyush
  - Status: Open
- Risk: Native background bonus (B2/B3) pulls hours from Track A.
  - Impact: Track A items slip; rubric penalized for unfinished ★.
  - Mitigation: Hard rule — bonus work starts only after Track A is green and video is recorded.
  - Owner: Piyush
  - Status: Open
- Risk: Firestore security rules too strict or too permissive.
  - Impact: Either functional breakage under test or open-to-world data.
  - Mitigation: Author rules narrowly scoped by `request.auth.uid` matching `senderUid`/`recipientUid`; test in Firebase Emulator Suite before deploy.
  - Owner: Piyush
  - Status: Open
- Risk: Retry currently restarts files rather than resuming offsets.
  - Impact: Slow recovery on large-file mid-transfer drops.
  - Mitigation: Land B2/B3 for true resume via native Firebase Storage SDK; document limitation honestly if bonus slips.
  - Owner: Piyush
  - Status: Open
- Risk: OEM battery killers on Android may drop the foreground service.
  - Impact: Bonus B demo fragile on non-stock Android.
  - Mitigation: Run demo on stock Android emulator; document OEM caveat in README.
  - Owner: Piyush
  - Status: Open

## 9. Decision Log
- Date: 2026-04-19
  - Decision: Build the client foundation around typed domain contracts and local anonymous identity before Firebase/relay integration.
  - Why: Locks system boundaries early; backend and native layers get stable interfaces.
  - Tradeoff: End-to-end transfer not available until later slice.
- Date: 2026-04-19
  - Decision: Initialize Firebase from `--dart-define` values, not checked-in secret files.
  - Why: Keeps secrets out of repo; reproducible Android/iOS setup without generated local files.
  - Tradeoff: Real-device verification depends on supplying correct platform-specific values per build.
- Date: 2026-04-19
  - Decision: Use `file_picker` for the core sender-drafting slice.
  - Why: Core rubric is end-to-end transfer, not picker polish. Bonus D is a drop-in replacement via Strategy pattern.
  - Tradeoff: Requires honest README note that native picker is intentionally the bonus path.
- Date: 2026-04-19
  - Decision: Use Firestore transfer documents as the single control-plane source of truth before adding byte transport.
  - Why: Unlocks cross-device inbox, accept/reject, and shared status transitions without waiting on data-plane decisions.
  - Tradeoff: Nothing — this is the correct industry pattern (event log + listeners).
- Date: 2026-04-19
  - Decision: Use direct Firebase Storage upload as the data plane.
  - Why: Real bytes moving with minimum risk; native SDK pause/resume and TLS out of the box; clean seam for the later native-background engine behind the same `TransferEngine` interface.
  - Tradeoff: Current retry restarts files; true chunk resume lands with B2/B3.
- Date: 2026-04-20
  - Decision: Closed-app discovery via Firebase Cloud Function on Blaze (Option A), not client-side fallback.
  - Why: ★ requirement in the brief; Option A is the only approach that wakes a truly killed app. Free-tier cost at demo volume is $0.
  - Tradeoff: Blaze enablement is a prerequisite; ~30 min of TypeScript + deploy time.
- Date: 2026-04-20
  - Decision: Partial-failure isolation implemented at the engine layer, not at the Firestore doc layer.
  - Why: Engine already owns per-file state transitions; moving the retry boundary up would leak transfer concerns into UI.
  - Tradeoff: Engine file gains complexity; offset by clearer state machine in one place.
- Date: 2026-04-20
  - Decision: Accept "one real + one emulator" setup (iPhone real + Android emulator on Mac).
  - Why: Brief explicitly allows it and the owner has exactly this hardware set.
  - Tradeoff: Android OEM-specific quirks won't be demonstrable; called out in README.

## 10. Session Log

### Session 2026-04-19 16:13
- Planned work: Scaffold Flutter codebase, replace default template with production foundation.
- Completed work: App shell, routing, theme, secure local identity, typed transfer/recipient contracts, Pigeon scaffold, README baseline, `.env.example`.
- Evidence: `flutter analyze` + `flutter test` green.
- Blocker: Firebase, FCM, Firestore reservation, relay deployment pending.
- Next step: Anonymous auth, short-code reservation/lookup, first real send/inbox backend path.

### Session 2026-04-19 16:41
- Planned work: Firebase bootstrap, hybrid identity, recipient lookup.
- Completed work: Runtime Firebase config, bootstrap service, hybrid identity repo, Firestore reservation, recipient lookup UI + controller.
- Evidence: `flutter analyze` + `flutter test` green; `.env.example` + README updated.
- Blocker: Real Firebase creds + device validation pending.
- Next step: Configure live Firebase, validate on devices, start first real transfer draft flow.

### Session 2026-04-19 16:46
- Planned work: Harden addressing with user-facing actions and tests.
- Completed work: Copy-code + refresh-registration, controller tests for malformed/self-send/missing.
- Evidence: tests green.
- Blocker: Backend-backed registration still needs live Firebase + device verification.
- Next step: Configure Firebase, validate on devices.

### Session 2026-04-19 18:55
- Planned work: First M2 slice — pick files, validate, create local draft.
- Completed work: `file_picker` integration, file-selector abstraction, MIME inference, draft validator, in-memory transfer repo, composer controller, send-screen UI, outgoing draft cancellation.
- Evidence: `flutter analyze` + `flutter test` green with new controller + validator coverage.
- Blocker: Send flow ends at draft creation; upload/download + relay transport + realtime delivery still missing.
- Next step: Remote transfer records + first upload initiation path.

### Session 2026-04-19 19:08
- Planned work: Replace inbox placeholder with real shared transfer feed.
- Completed work: Firestore-backed transfer creation/watch, hybrid transfer repo with local fallback, recipient-aware creation, live inbox, accept/reject actions.
- Evidence: tests green.
- Blocker: Actual bytes still don't move; live-project/device validation pending.
- Next step: Connect first upload initiation path with shared progress.

### Session 2026-04-19 19:20
- Planned work: Refresh tracker against actual repo state.
- Completed work: Expanded left-to-do, added ordered remaining-work checklist, refreshed partial statuses/evidence.
- Evidence: `PROJECT_TRACKER.md` updated.
- Blocker: Transport/data-plane gap + live validation.
- Next step: Implement upload initiation and shared progress.

### Session 2026-04-19 19:42
- Planned work: Connect first real sender upload path with shared progress on both screens.
- Completed work: Remote-context resolver, extended repository contract, `FirebaseStorageTransferEngine`, upload start/cancel, shared per-file + aggregate progress rendering.
- Evidence: `flutter analyze` + `flutter test` green; `TransferProgressSummary` reused by send + inbox.
- Blocker: Receiver download/save, rules, live validation, stronger resumable behavior pending.
- Next step: Validate on devices; build recipient-side download + remaining starred edge cases.

### Session 2026-04-20 (in progress)
- Planned work: Audit repo against brief; rewrite tracker with prioritized Track A (P0) + Track B (bonus) plan; confirm design-pattern discipline; pick FCM delivery strategy.
- Completed work: Full codebase audit (all `lib/` + pigeons + android/ + ios/ + tests); gap matrix against brief ★ items + bonus; architectural-principles section; prioritized Track A/B plan with file-level references; decision on Option A (Cloud Function on Blaze) for closed-app discovery.
- Evidence: `PROJECT_TRACKER.md` rewritten with current state of code and remaining work.
- Blocker: Blaze billing not yet enabled on the Firebase project (required for A8).
- Next step: Enable Blaze → start Track A in order (A1 → A2 → A3 → ...); Track B only after A11 is shipped.

## 11. Final Submission Checklist
- [ ] Signed debug APK tested on clean Android device/emulator — A11.
- [ ] iPhone build path verified via Xcode — A11.
- [ ] Source available (GitHub link or zipped repo in Drive) — A11.
- [ ] `.env.example` included; secrets excluded — already in repo; audit before zip.
- [ ] README finalized — A10.
- [ ] Architecture diagram (ASCII) in README — A10.
- [ ] AI tool usage disclosed honestly — A10.
- [ ] Video walkthrough recorded — A11.
- [ ] Drive folder assembled with public-view link — A11.
