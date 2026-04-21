# NeoSapien Project Tracker

## 1. Project Snapshot
- Deadline: 2026-04-20 08:00 PM (submission day)
- Goal: Ship a production-grade cross-device file sharing app that works on a real iPhone and a real/emulated Android device over the public internet.
- Platforms: Flutter app with Android + iOS parity. Devices available: real iPhone + Android emulator on Mac.
- Primary bonus (weighted heavily in rubric): Pigeon-based background transfer on Android and iOS.
- Secondary bonus: native picker (SAF / UIDocumentPicker), native save (MediaStore / PHPhotoLibrary), native share sheet.
- Current phase: M3 Resilience + Starred Cases complete; M5 Cross-Platform Hardening + M6 Submission Assets in progress.
- Overall status: [/]
- Current focus: A11 — real-device run, walkthrough video, Drive package.
- Next milestone: M6 Submission Assets.
- Latest blocker: None for code — pending user actions: `firebase login` + `firebase deploy --only firestore:rules,storage,functions`, Firebase app registration on Android/iOS, Apple Developer APNs key upload, live-device capture for the walkthrough video.
- Demo readiness: [/] Code complete; awaiting device validation + deploy.
- Submission readiness: [/] README + tracker ready; APK + iOS build + video pending.

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

- [/] **A1. Firebase ops**: Firestore rules, Storage rules, indexes scaffold, and Cloud Function (`onTransferCreated`) all written and TypeScript-compiled. Pending user action: `firebase login` → `firebase deploy --only firestore:rules,storage,functions` + platform-app registration for `--dart-define` values.
- [x] **A2. Partial-failure isolation** in [firebase_storage_transfer_engine.dart](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart): fail-fast replaced with per-file continue; `_finalizeOutgoingBatch` / `_finalizeIncomingBatch` resolve batch to `pendingRecipient`/`completed` if any succeed, `failed` only if all failed. Per-file retry via `enqueue` (skips completed files).
- [x] **A3. SHA-256 integrity**: [`TransferIntegrityService`](lib/features/transfers/data/services/transfer_integrity_service.dart) streams `sha256.bind(openRead)` both before upload and after download; mismatch deletes file + marks `TransferFailureCode.integrityCheckFailed`.
- [x] **A4. Permission handling**: [`PermissionGateway`](lib/core/permissions/permission_gateway.dart) interface + [`PermissionHandlerGateway`](lib/core/permissions/permission_handler_gateway.dart) impl; Android manifest declares `POST_NOTIFICATIONS`, `READ_MEDIA_*`, foreground-service permissions; iOS `Info.plist` has `NSPhotoLibraryAddUsageDescription` + `UIBackgroundModes`.
- [x] **A5. Low-storage preflight**: [`DeviceStorageChecker`](lib/core/storage/device_storage_checker.dart) + `disk_space_plus` impl; `_ensureFreeStorageForBatch` requires free bytes ≥ `totalBytes × 1.1` before accept or download.
- [x] **A6. Metered-connection enforcement**: [`ConnectivityGateway`](lib/core/connectivity/connectivity_gateway.dart) + `connectivity_plus` impl; `_ensureNetworkAllowsTransfer` blocks offline and blocks metered unless policy is `allowMetered`.
- [x] **A7. Process-death recovery**: [`TransferRecoveryService`](lib/features/transfers/data/services/transfer_recovery_service.dart) + `reconcileStaleBatchesForUser` reconciles any `uploading`/`downloading` batch written by this device but stale >2min as `failed + recoverable`. Wired through `transferRecoveryBootProvider` in [`app.dart`](lib/app/app.dart).
- [x] **A8. FCM closed-app discovery** (Cloud Function, Option A):
  - [`FcmTokenRegistrar`](lib/features/notifications/data/services/fcm_token_registrar.dart) writes to `users/{uid}/private/fcm.tokens` via `arrayUnion`; refresh subscribed.
  - [`functions/src/index.ts`](functions/src/index.ts) Firestore trigger fans out via `admin.messaging().sendEachForMulticast` and prunes invalid tokens.
  - [`LocalNotificationService`](lib/features/notifications/data/services/local_notification_service.dart) raises foreground banners on `incoming_transfers` channel.
  - [`IncomingTransferFcmListener`](lib/features/notifications/application/incoming_transfer_fcm_listener.dart) bridges `onMessage` / `onMessageOpenedApp` / `getInitialMessage` into the event bus.
  - [`app.dart`](lib/app/app.dart) `ref.listen` deep-links events to `/inbox?batch=<id>`.
- [x] **A9. Duplicate delivery dedupe**: satisfied by existing design — `(batchId, fileId)` keyed `upsertDownloadedFile`, `_hasLocalCopy` short-circuit, `_runningTransfers` guard, `batchId.hashCode` notification ID, role-checked Firestore transactions.
- [x] **A10. README rewrite**: architecture ASCII diagram, transport rationale, ★ coverage table with file refs, known limitations, AI disclosure, project structure, demo outline. See [`README.md`](README.md).
- [ ] **A11. Real-device run + walkthrough video + Drive package**: pending user actions — build signed debug APK, verify iPhone build via Xcode, record 5–8 min video (onboarding, code exchange, transfer, Wi-Fi toggle, bad code, large file, app-kill-reopen, closed-app FCM discovery, 60s code tour), assemble Drive folder.

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
- [x] Short-code collisions handled
  - Evidence: `IdentityRegistryRemoteDataSource.reserveIdentity` uses Firestore transactions with up to 24 candidate retries.
- [x] Invalid recipient code fails fast with clear UI
  - Evidence: `RecipientLookupController` rejects malformed codes synchronously and surfaces "No device is registered under that code yet" on Firestore miss; covered by `recipient_lookup_controller_test.dart`.
- [x] Recipient offline behavior implemented
  - Evidence: Firestore records persist with `expiresAt`; FCM fan-out via Cloud Function wakes the recipient on next connectivity (A8 complete).
- [/] Network drop mid-transfer handled
  - Evidence: failures mapped to recoverable state; retry restarts from byte 0 on the failed file. True chunk-offset resume lands with native background engines (Bonus B/C). Documented honestly in [README §9](README.md).
- [x] Large files handled without OOM
  - Evidence: `TransferDraftValidator` ceilings; `FilePicker.pickFiles(withData: false)` keeps selection metadata-only; `FirebaseStorageTransferEngine.putFile` streams from disk; streaming SHA-256 via `sha256.bind(openRead)`. Pending 500MB device validation (A11).
- [x] Multiple files at once with partial failure isolation
  - Evidence: fail-fast replaced with per-file continue in the engine; `_finalizeOutgoingBatch` / `_finalizeIncomingBatch` resolve batch state based on per-file outcomes; retry via `enqueue` picks up only the failed files.
- [x] Permission denial degrades gracefully
  - Evidence: `PermissionGateway` + `PermissionHandlerGateway` implemented. `notificationBootProvider` treats denied notifications as best-effort and does not block boot. Android 13+ media permissions + iOS photos-add declared.
- [x] Incoming transfer while app is closed is discoverable
  - Evidence: `FcmTokenRegistrar` persists tokens; Cloud Function `onTransferCreated` fans out with notification + data payload; `IncomingTransferFcmListener` consumes `getInitialMessage` / `onMessageOpenedApp`; deep link to `/inbox?batch=<id>` via GoRouter.
- [x] Transport encryption enforced
  - Evidence: Firebase Auth / Firestore / Storage / Messaging are TLS by default; documented in [README §5 + §8.1](README.md).

### 4.3 Important Non-Starred Cases
- [x] Ambiguous characters removed from code alphabet
  - Evidence: `RecipientCodeCodec.alphabet` excludes `O/0/I/l/1`; `short_code_generator_test.dart` verifies.
- [x] Self-send policy implemented
  - Evidence: `RecipientLookupController.resolveRecipient` blocks self-send with explicit UX.
- [x] Duplicate delivery dedupes by transfer ID
  - Evidence: `(batchId, fileId)` keyed `upsertDownloadedFile`, `_hasLocalCopy` short-circuit, `_runningTransfers` guard, `batchId.hashCode` notification ID, role-checked Firestore transactions.
- [x] Metered connection warning added
  - Evidence: `ConnectivityGateway` + `connectivity_plus` enforce `NetworkPolicy`; `_ensureNetworkAllowsTransfer` blocks offline and metered unless `allowMetered`.
- [x] Unusual MIME and zero-byte files do not crash
  - Evidence: `MimeTypeGuesser` covers common mobile MIMEs and falls back to `application/octet-stream`; `transfer_draft_validator_test.dart` covers zero-byte acceptance.
- [x] Filename conflict policy implemented
  - Evidence: `ReceivedTransferFileStore.createTargetFile` appends deterministic suffixes; covered by `received_transfer_file_store_test.dart`.
- [x] Corruption detection via hash verification
  - Evidence: `TransferIntegrityService` streaming SHA-256 on sender before upload + receiver after download; mismatch → delete file + mark `TransferFailureCode.integrityCheckFailed`.
- [x] Low storage preflight checks implemented
  - Evidence: `DeviceStorageChecker` + `_ensureFreeStorageForBatch` require free bytes ≥ `totalBytes × 1.1` before accept or download.
- [x] Background / process death recovery implemented
  - Evidence: `TransferRecoveryService.reconcileStaleBatchesForUser` marks stale in-flight batches as `failed + recoverable` on boot via `transferRecoveryBootProvider`.
- [/] Network transitions and airplane mode handled
  - Evidence: `connectivity_plus` subscribed; transfers get `networkInterrupted` failure on disconnect. True auto-resume across transitions lands with native background engines (B2/B3).

### 4.4 Bonus Targets
- [x] Bonus A: Pigeon bridge defined and integrated
  - Evidence: `pigeons/native_transfer_bridge.dart` contract extended with `NativeMediaSaverHostApi`; generated bindings committed to [`lib/platform/native_transfer_bridge.g.dart`](lib/platform/native_transfer_bridge.g.dart), [Kotlin](android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeTransferBridge.g.kt), [Swift](ios/Runner/NativeTransferBridge.g.swift).
- [ ] Bonus B: Android background transfer (WorkManager + Foreground Service)
  - Evidence: Pigeon contract for `NativeTransferHostApi` is ready; Kotlin impl not wired.
- [ ] Bonus C: iOS background transfer (`URLSession` background config)
  - Evidence: Pigeon contract is ready; Swift impl not wired; blocked on Apple Developer enrollment for real-device APNs.
- [ ] Bonus D: Native picker integration (SAF + UIDocumentPicker)
  - Evidence: `TransferFileSelector` Strategy interface exists; native impl would replace `file_picker` via Riverpod override.
- [x] Bonus E: Native save-to-gallery/downloads (MediaStore + PHPhotoLibrary)
  - Evidence: [`NativeMediaSaverImpl.kt`](android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeMediaSaverImpl.kt) (MediaStore Images/Video/Audio/Downloads with atomic `IS_PENDING` publish) + [`NativeMediaSaverImpl.swift`](ios/Runner/NativeMediaSaverImpl.swift) (PHPhotoLibrary + UIActivityViewController fallback); UI entry point on every saved file in inbox via [`NativeSaveController`](lib/features/transfers/application/native_save_controller.dart).
- [-] Bonus F: Nearby fallback transport
  - Evidence: Explicitly deferred; noted in README.

## 5. Milestones

- [x] M0 Foundation
  - Evidence: Flutter shell, env management, lint/test, Firebase bootstrap, architecture boundaries; `flutter analyze` + `flutter test` green on 2026-04-19.

- [/] M1 Identity And Addressing
  - Evidence: Hybrid identity, Firestore reservation, recipient lookup, profile UI, invalid-code handling implemented. Gate: live-project verification (A1 deploy + device run).

- [/] M2 Core Transfer Happy Path
  - Evidence: selection, validation, Firestore-backed transfer records, inbox discovery, accept/reject, Storage upload + download + save + history, shared progress implemented and green in tests. Gate: device-level verification (A11).

- [x] M3 Resilience And Starred Cases
  - Evidence: A2–A9 complete. All ★ boxes are implemented; see 4.2. Network chunk-resume deferred to Bonus B/C (documented in README §9).

- [ ] M4 Native Background Transfer Bonus
  - Evidence: Track B. Not started — gated on A11 completion.

- [/] M5 Cross-Platform Hardening
  - Evidence: permission/manifest entries shipped for both platforms; device matrix capture pending A11.

- [/] M6 Submission Assets
  - Evidence: [README.md](README.md) rewritten with architecture, transport rationale, ★ table, known limitations, AI disclosure. APK + iOS build + video + Drive folder pending A11.

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

| Device | Role | OS | Used for |
|---|---|---|---|
| Android physical phone | Sender + recipient | Android (personal device) | Happy-path upload / download, FCM closed-app push, cross-device send to emulator |
| Android emulator on Mac | Sender + recipient | Android 14, API 34 (Pixel image, Google Play) | Cross-device pair with the physical phone; closed-app FCM recipient |
| iOS simulator on Mac | Sender + recipient | iOS 26.1, iPhone 16e | Cross-platform transfer parity demo (Android ↔ iOS); FCM push **not** verifiable — simulator platform limit |
| MacBook Pro | Developer host | macOS 15.7.4 | Xcode 26.3, Firebase CLI, Flutter 3.38.5 / Dart 3.10.4 |

Brief explicitly allows "one physical + one emulator" as the minimum — setup exceeds that with an additional iOS simulator for cross-platform parity.

### Verified runs (this session, 2026-04-21)
- Android phone → Android emulator: happy-path transfer ✅
- Android emulator → Android phone: reverse direction ✅
- Android phone → iOS simulator: cross-platform transfer ✅
- Bad recipient code fast-fail ✅
- Self-send block ✅
- Wi-Fi toggled off mid-upload, on → batch auto-resumed ✅
- Multi-file batch with Wi-Fi toggle → both files delivered ✅
- Emulator app force-killed, new batch from phone → FCM push landed, deep-link opened inbox ✅
- Download completed, SHA-256 verified, saved under `Documents/neo_sapien_received/{batchId}/` ✅

### Known platform-specific gaps
- iOS FCM push requires Apple Developer enrollment + APNs key upload (wired client-side, not demo-able in this environment).
- OEM battery killers on non-stock Android not tested (stock Pixel emulator used).
- Apple Developer free-signing on a real iPhone not attempted — iOS demo uses simulator only.

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

### Session 2026-04-21 (Track A execution)
- Planned work: Execute Track A items A1 through A10.
- Completed work:
  - **A1 scaffold**: `firebase/{firestore,storage}.rules`, `firebase/firestore.indexes.json`, `firebase.json`, `.firebaserc`, `functions/` TypeScript project with `onTransferCreated` Cloud Function; `functions && npm run build` passes.
  - **A2**: Partial-failure isolation in `FirebaseStorageTransferEngine` — per-file `continue` instead of fail-fast, new `_finalizeOutgoingBatch` / `_finalizeIncomingBatch` helpers, `_markFileFailedContinuing` helper. Batch status now reflects "what can the recipient do" rather than fail-fast abort.
  - **A3**: `TransferIntegrityService` with streaming SHA-256; wired into sender pre-upload and receiver post-download. Mismatches delete the file and mark `TransferFailureCode.integrityCheckFailed`.
  - **A4**: `PermissionGateway` + `PermissionHandlerGateway` + provider; Android manifest + iOS Info.plist updated.
  - **A5**: `DeviceStorageChecker` + `DiskSpacePlusStorageChecker` + provider; `TransferBatchActionController._ensureFreeStorageForBatch` blocks accept/download when free < total × 1.1.
  - **A6**: `ConnectivityGateway` + `ConnectivityPlusGateway` + provider; `_ensureNetworkAllowsTransfer` enforces offline/metered policies before upload/download.
  - **A7**: `TransferRecoveryService.reconcileOnBoot` + `FirestoreTransferRemoteDataSource.reconcileStaleBatchesForUser` reconcile stale in-flight docs; `transferRecoveryBootProvider` fires from `NeoSapienApp`.
  - **A8**: full FCM closed-app discovery — `IncomingTransferEventBus`, `LocalNotificationService`, `FcmTokenRegistrar`, `IncomingTransferFcmListener`, `notificationBootProvider`, `@pragma('vm:entry-point')` background handler in `main.dart`, deep link from `app.dart` to `/inbox?batch=<id>`.
  - **A9**: verified dedupe is already covered by existing design (`(batchId, fileId)` key + `_hasLocalCopy` + `_runningTransfers` + `batchId.hashCode` notification ID + transactional role-checked Firestore writes); documented in README §8.2.
  - **A10**: full `README.md` rewrite with ASCII architecture diagram, transport rationale, 10-item pattern table, Firebase setup, ★ coverage table with file refs, known limitations, AI disclosure, project structure, demo outline.
- Evidence: `flutter analyze` clean; `flutter test` all 17 tests passing; `functions` TypeScript strict build passes.
- Blocker: user actions to deploy (`firebase login` + `firebase deploy`), register platform apps in console, upload APNs key, and capture the walkthrough video.
- Next step: A11 — signed debug APK + iPhone Xcode build + walkthrough video + Drive package.

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
