# NeoSapien Project Tracker

## 1. Project Snapshot
- Deadline: 2026-04-20 08:00 PM
- Goal: Ship a production-grade cross-device file sharing app that works on a real Android phone and a real iPhone.
- Platforms: Flutter app with full Android + iPhone parity.
- Primary bonus: Pigeon-based background transfer on Android and iOS.
- Secondary bonus: Native picker + native save flow if core is already green.
- Current phase: M2 Core Transfer Happy Path
- Overall status: [/]
- Current focus: Validate the now-complete Firebase Storage upload/download happy path on real devices and harden the remaining failure semantics around it.
- Next milestone: M2 Core Transfer Happy Path
- Latest blocker: Firestore/Storage rules, live Firebase/device validation, and stronger mid-transfer recovery are still pending; retry currently restarts the incomplete file cleanly instead of resuming chunk offsets.
- Demo readiness: [ ] Not ready
- Submission readiness: [ ] Not ready

## 1A. Progress Summary

### Done So Far
- Flutter project scaffolded at the repo root with both Android and iOS targets.
- Production app shell created with routing, theme system, bottom navigation, and feature-first folder boundaries.
- Core architecture foundation added: `app`, `core`, `features`, and `shared` layers with typed contracts instead of template/demo code.
- Local anonymous identity provisioning implemented with secure storage persistence.
- Unambiguous short-code format locked and validated in code and tests.
- Dashboard, send, inbox, and profile screens added as real feature surfaces for the next milestones.
- Transfer domain contracts added: typed statuses, failure codes, repository interfaces, network policy, and transfer entities.
- Pigeon contract scaffold added for future Android and iOS native background-transfer integration.
- Project hygiene added: stricter analyzer rules, `.env.example`, project-specific README baseline, updated `.gitignore`.
- Firebase runtime bootstrap added through `--dart-define` configuration instead of checked-in secret files.
- Hybrid identity repository added: local fallback, Firebase anonymous auth, and Firestore-backed short-code reservation when configured.
- Recipient lookup controller and send-screen lookup UI added with fast invalid-code, missing-code, and self-send failure handling.
- Profile actions added for copying the short code and retrying registration after Firebase setup changes.
- Sender-side file picking, preflight validation, and local transfer-draft creation are now implemented with an outgoing draft list in the send flow.
- Draft validation now enforces file-count, per-file, and total batch-size ceilings without loading file bytes into memory.
- Transfer draft tests added for selection, draft creation, and large-file / invalid-source guardrails.
- Firestore-backed transfer metadata creation is now wired through the shared transfer repository when Firebase is configured.
- The inbox now renders live incoming transfer records and supports accept/reject decisions through the same repository contract.
- Transfer action tests now cover recipient-side accept handling in addition to sender draft creation.
- Sender-side upload initiation is now wired through a Firebase Storage transfer engine that updates Firestore with batch and per-file progress.
- Send and inbox screens now render shared per-file plus aggregate upload progress from the same Firestore-backed transfer state.
- Recipient-side download/save is now wired through the same Firebase Storage engine, writing received files into app storage, persisting saved paths locally, and surfacing completed history in the inbox.
- Receiver-side save conflicts now rename deterministically inside the per-batch local save directory instead of clobbering an existing file.
- Foundation validation completed: `flutter analyze` passes and `flutter test` passes after the Firebase/addressing slice.

### Left To Do
- Supply live Firebase project values, enable the required Firebase services, and validate bootstrap/registration/lookup on Android and iPhone.
- Add Firestore rules, Storage rules, and any required indexes for `users`, `codes`, and `transfers`.
- Validate the current direct-to-Firebase-Storage upload path on real devices and decide whether to keep it or swap the data plane to a Cloud Run resumable relay.
- Validate and harden the new receiver download/save flow on real devices, especially around low storage, permissions, and OEM/background behavior.
- Harden all starred edge cases: offline recipient semantics, network-drop handling, large-file streaming, multi-file failure isolation, permission denial, and closed-app discovery.
- Add integrity/hash verification, low-storage checks, dedupe, filename conflict handling, network transition handling, and process-death recovery.
- Implement bonus/native work only after the core path is stable: Pigeon codegen hookup, Android background transfer, iOS background transfer, and optional native picker/save.
- Finish the submission assets: tested APK, iPhone run path, final README, video walkthrough, device matrix, and Drive package.

## 1B. Remaining Work In Order
- [ ] Configure a live Firebase project for Android and iPhone and prove bootstrap, anonymous auth, short-code reservation, recipient lookup, accepted upload start, and shared progress on devices.
- [ ] Add Firestore rules, Storage rules, indexes, and a documented local/dev setup for the current control-plane collections.
- [ ] Harden the current data plane into the final transport choice: either keep direct Firebase Storage with a defensible restart policy or replace it with the planned Cloud Run resumable relay.
- [ ] Validate and harden recipient-side download/save on physical devices, including low-storage handling, permission edge cases, and reopened-app behavior.
- [ ] Implement starred delivery/failure behavior: recipient offline handling, network interruption recovery, large-file streaming, multiple-file partial failure isolation, and graceful permission denial.
- [ ] Add closed-app discovery with notifications/deep links plus honest README coverage of OEM/background limits.
- [ ] Implement integrity, storage, and recovery hardening: hash verification, low-storage checks, duplicate dedupe, save conflicts, network transitions, airplane mode, and process-death recovery.
- [ ] Only after the core flow is stable, finish the bonus/native work: generated Pigeon bridge, Android background transfer, iOS background transfer, and optional native picker/save work.
- [ ] Finish QA, real-device parity evidence, walkthrough video, and final submission packaging.

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

## 4. Rubric Coverage

### 4.1 Core Requirements
- [x] Anonymous onboarding with local identity provisioning
  - Done when: First launch provisions identity without email, password, or phone number.
  - Evidence: `LocalIdentityRepository` + `CurrentIdentityController` provision and persist a local identity via secure storage; surfaced in dashboard/profile and covered by passing widget and unit tests on 2026-04-19.
- [/] Short-code identity generation and registration
  - Done when: User receives a stable human-friendly code and it resolves correctly from another device.
  - Evidence: `HybridIdentityRepository` now attempts Firestore-backed registration with collision retries and persists the reserved code locally; still pending validation against a real Firebase project.
- [/] Send one or more media files to a short code
  - Done when: Images, video, audio, documents, and arbitrary files can be sent in a single batch.
  - Evidence: sender-side file picking, MIME inference, preflight validation, transfer creation, recipient accept/reject, sender upload start, recipient download/save, and Firebase Storage-backed shared transfer progress now flow through `TransferDraftComposerController`, `HybridTransferRepository`, `FirebaseStorageTransferEngine`, the local download-state data source, and the shared Firestore transfer feed. Live device validation is still pending.
- [/] Works across distance / internet relay
  - Done when: Transfers do not depend on proximity, LAN, or localhost.
  - Evidence: identity, recipient lookup, transfer creation, inbox discovery, sender-side uploads, and recipient-side downloads now run through Firebase Auth, Firestore, and Firebase Storage over the internet when configured; the final resumable relay decision and device validation are still pending.
- [ ] Real-device proof path
  - Done when: At least one Android phone and one iPhone complete end-to-end tests.
  - Evidence:
- [/] Real-time progress and final success/failure states
  - Done when: Sender and recipient both see state transitions without manual refresh.
  - Evidence: outgoing uploads and incoming downloads now write aggregate and per-file progress into Firestore so both the sender queue and recipient inbox update live from the same transfer documents, while local saved paths are merged back into completed receiver history. Real-device verification is still pending.

### 4.2 Starred Edge Cases
- [/] Short-code collisions handled
  - Done when: Reservation is guaranteed unique or collision retries are transparent.
  - Evidence: `IdentityRegistryRemoteDataSource.reserveIdentity` retries candidate codes and uses Firestore transactions to avoid duplicate claims; still pending live-project verification.
- [/] Invalid recipient code fails fast with clear UI
  - Done when: Sender cannot start upload to a non-existent code.
  - Evidence: `RecipientLookupController` blocks malformed codes immediately and shows a clear "No device is registered under that code yet" message when Firestore lookup misses; covered by `recipient_lookup_controller_test.dart`.
- [/] Recipient offline behavior implemented
  - Done when: Queued delivery or explicit rejection policy is implemented and documented.
  - Evidence: remote transfer records now persist in Firestore and can appear in the recipient inbox when the user later opens the app, but TTL enforcement, explicit expiry behavior, and push-based discovery are still pending.
- [/] Network drop mid-transfer handled
  - Done when: Resume, restart, or fail-cleanly policy works and is tested.
  - Evidence: `FirebaseStorageTransferEngine` now maps both upload and download failures into recoverable failed states and exposes retry, which currently restarts the incomplete file cleanly rather than resuming chunk offsets; device validation and a stronger resumable strategy are still pending.
- [/] Large files handled without OOM
  - Done when: Hard size ceiling is enforced and near-limit files stream safely.
  - Evidence: `TransferDraftValidator` now enforces per-file and per-batch ceilings before upload, `FilePicker.pickFiles(withData: false)` keeps selection metadata-only, and `FirebaseStorageTransferEngine.putFile` streams bytes from disk instead of loading whole files into memory; resumable chunk recovery is still pending.
- [/] Multiple files at once with partial failure isolation
  - Done when: One file can fail without killing the whole batch.
  - Evidence: multi-file batch selection, per-file metadata, and per-file progress are implemented in the draft, upload, download, and remote transfer record layers, and already-saved receiver files are preserved across retry, but a failed file still stops the active batch today so full partial-failure isolation is still pending.
- [ ] Permission denial degrades gracefully
  - Done when: Denied storage/photos/notifications does not crash the app.
  - Evidence:
- [ ] Incoming transfer while app is closed is discoverable
  - Done when: Notification/deep-link or equivalent recipient entry path works.
  - Evidence:
- [/] Transport encryption enforced
  - Done when: HTTPS/TLS is used end to end and documented in README.
  - Evidence: the current Firebase Auth, Firestore, and Firebase Storage client paths use TLS-backed Firebase connections by default; final README coverage plus any future relay transport documentation are still pending.

### 4.3 Important Non-Starred Cases We Still Intend To Handle
- [x] Ambiguous characters removed from code alphabet
  - Done when: `O/0`, `I/l/1` style ambiguity cannot be issued.
  - Evidence: `RecipientCodeCodec.alphabet` excludes ambiguous characters and `short_code_generator_test.dart` verifies generated codes avoid them.
- [x] Self-send policy implemented
  - Done when: Self-send is either blocked or explicitly supported with clear UX.
  - Evidence: `RecipientLookupController.resolveRecipient` compares the target code against the current local identity and blocks self-send with explicit UI copy; covered by `recipient_lookup_controller_test.dart`.
- [ ] Duplicate delivery dedupes by transfer ID
  - Done when: Receiver does not duplicate files due to retries.
  - Evidence:
- [/] Metered connection warning added
  - Done when: Large cellular transfers require an explicit confirmation.
  - Evidence: `NetworkPolicy.confirmOnMetered` is now modeled and selectable in the sender draft flow, but it is not yet enforced by the upload/data-plane logic.
- [/] Unusual MIME and zero-byte files do not crash
  - Done when: `.heic`, `.webp`, `.mov`, extensionless, and empty files are handled.
  - Evidence: `MimeTypeGuesser` now classifies common mobile formats with `application/octet-stream` fallback, and `transfer_draft_validator_test.dart` explicitly covers zero-byte-file acceptance; end-to-end transport/save coverage is still pending.
- [x] Filename conflict policy implemented
  - Done when: Save collisions rename deterministically.
  - Evidence: `ReceivedTransferFileStore.createTargetFile` now saves incoming files under a per-batch app-storage directory and deterministically appends ` (2)`, ` (3)`, and so on when a filename already exists; covered by `received_transfer_file_store_test.dart`.
- [ ] Corruption detection via hash verification
  - Done when: Sender hash and receiver hash are compared and mismatch is actionable.
  - Evidence:
- [ ] Low storage preflight checks implemented
  - Done when: Receive path refuses transfers that cannot fit locally.
  - Evidence:
- [ ] Background / process death recovery implemented
  - Done when: In-progress state is restored or failed cleanly on next launch.
  - Evidence:
- [ ] Network transitions and airplane mode handled
  - Done when: Reconnect and reconciliation logic are tested.
  - Evidence:

### 4.4 Bonus Targets
- [/] Bonus A: Pigeon bridge defined and integrated
  - Done when: Dart <-> native contracts are generated and used for transfer actions/events.
  - Evidence: `pigeons/native_transfer_bridge.dart` now defines the host and Flutter APIs; code generation and native hookup are still pending.
- [ ] Bonus B: Android background transfer
  - Done when: Foreground service / WorkManager keeps transfer alive and progress is reconciled.
  - Evidence:
- [ ] Bonus C: iOS background transfer
  - Done when: Background URLSession continues or reconciles transfer correctly after relaunch.
  - Evidence:
- [ ] Bonus D: Native picker integration
  - Done when: OS-native document picker is used through platform channels instead of a package.
  - Evidence:
- [ ] Bonus E: Native save-to-gallery/downloads
  - Done when: Received media can be saved via MediaStore / Photos or Files integration.
  - Evidence:
- [-] Bonus F: Nearby fallback transport
  - Done when: Nearby discovery and peer transfer work without breaking the cloud path.
  - Evidence:

## 5. Milestones

- [/] M0 Foundation
  - Done when: Flutter app skeleton, env management, CI/lint/test setup, Firebase project, and architecture boundaries are established.
  - Evidence: Flutter app scaffolded at repo root, `.env.example` expanded with Firebase keys, app shell and domain contracts implemented, runtime Firebase bootstrap added, `flutter analyze` clean, `flutter test` passing on 2026-04-19. Real Firebase project values and device verification are the remaining M0 gap.

- [/] M1 Identity And Addressing
  - Done when: Anonymous identity, short-code generation, lookup, profile display, and invalid code handling are working.
  - Evidence: hybrid identity registration, Firestore code reservation, recipient lookup repository, and send-screen lookup UI are implemented in code; live project verification is still pending.

- [/] M2 Core Transfer Happy Path
  - Done when: Cross-device upload/download works in both directions with progress and final statuses.
  - Evidence: sender-side file selection, preflight validation, network-policy choice, Firestore-backed transfer creation, live inbox discovery, accept/reject actions, Firebase Storage upload initiation, recipient download/save into app storage, completed receiver history, and shared sender/recipient progress are now implemented and covered by passing analyzer/tests; device validation and the final resumable transport decision are still pending.

- [ ] M3 Resilience And Starred Cases
  - Done when: All starred edge cases are implemented and verified on both platforms.
  - Evidence:

- [ ] M4 Native Background Transfer Bonus
  - Done when: Android and iOS native background transfer implementations are stable and reconciled in Flutter.
  - Evidence:

- [ ] M5 Cross-Platform Hardening
  - Done when: Real-device parity matrix passes and major non-starred failure cases are covered.
  - Evidence:

- [ ] M6 Submission Assets
  - Done when: README, APK, iOS build path, video walkthrough, and Drive folder are ready.
  - Evidence:

## 6. Workstream Tracker

### 6.1 Architecture And Foundation
- [x] Create feature modules and dependency boundaries
  - Done when: Presentation, application, domain, and data layers are separated.
  - Evidence: `lib/app`, `lib/core`, `lib/features`, and `lib/shared` are in place with identity data/application/domain separation and transfer contracts isolated from UI.
- [x] Define typed error model and transfer state machine
  - Done when: Failure codes and lifecycle states are explicit and not stringly typed.
  - Evidence: `core/errors/app_exception.dart` and `features/transfers/domain/entities/*` define typed failures, statuses, and policies.
- [x] Add strict linting, formatting, and test configuration
  - Done when: Quality gates are runnable and documented.
  - Evidence: stricter `analysis_options.yaml` added; `flutter analyze` and `flutter test` both passed on 2026-04-19.

### 6.2 Backend And Relay
- [/] Configure Firebase Auth, Firestore, FCM, Storage
  - Done when: Anonymous auth, realtime state, push, and storage are wired.
  - Evidence: Firebase packages added, runtime bootstrap service added, providers for auth/firestore/storage/messaging now exist, and sender uploads now write into Firebase Storage through `FirebaseStorageTransferEngine`; actual project credentials, security rules, and FCM/runtime verification remain pending.
- [/] Implement unique short-code reservation flow
  - Done when: Collision-safe registration exists.
  - Evidence: `IdentityRegistryRemoteDataSource` implements Firestore-backed `users/{uid}` and `codes/{shortCode}` writes with transaction-based reservation and retry.
- [ ] Deploy resumable relay on Cloud Run
  - Done when: Streaming upload/download and resumption path are available.
  - Evidence:
- [/] Add TTL expiry, signed access, and server validation
  - Done when: Transfer lifecycle rules are enforced server-side.
  - Evidence: remote transfer records now store `expiresAt` and typed status fields in Firestore, but expiry jobs, signed byte access, and server-side enforcement are still pending.

### 6.3 Flutter Transfer Experience
- [x] Onboarding and profile screen
  - Done when: User can see and share their code.
  - Evidence: dashboard/profile routes render the provisioned local identity and runtime configuration through the new app shell.
- [x] Recipient lookup and send composer
  - Done when: Sender can resolve code and prepare a batch.
  - Evidence: send screen now includes backend-backed recipient lookup with validation, self-send blocking, missing-recipient messaging, file picking, network-policy selection, and local transfer-draft creation.
- [/] Sender progress UI
  - Done when: Per-file and aggregate states are visible and actionable.
  - Evidence: the send flow now shows outgoing transfer records, batch-level controls, and a shared `TransferProgressSummary` with per-file plus aggregate upload progress wired to Firestore-backed state.
- [x] Recipient inbox and accept/reject flow
  - Done when: Incoming transfers are visible and can be acted on.
  - Evidence: inbox now watches shared transfer batches, renders incoming Firestore-backed transfers in real time, updates batch status through `TransferBatchActionController`, and mirrors sender upload progress through the same shared transfer documents.
- [ ] Download progress, save flow, and completed history
  - Done when: Receiver can save and review received files.
  - Evidence:

### 6.4 Android Native
- [ ] Implement Pigeon Android host API
  - Done when: Flutter can start, pause, resume, cancel, and query transfers natively.
  - Evidence:
- [ ] Implement WorkManager / foreground service path
  - Done when: Upload/download survives backgrounding under supported conditions.
  - Evidence:
- [ ] Implement Android notifications and deep links
  - Done when: Closed-app incoming transfers are discoverable.
  - Evidence:

### 6.5 iOS Native
- [ ] Implement Pigeon iOS host API
  - Done when: Flutter can drive native transfer behavior on iPhone.
  - Evidence:
- [ ] Implement background URLSession path
  - Done when: Upload/download reconcile correctly after suspension or relaunch.
  - Evidence:
- [ ] Implement iOS notifications and deep links
  - Done when: Closed-app incoming transfers are discoverable.
  - Evidence:

### 6.6 Reliability And Edge Cases
- [ ] Disk-space checks
  - Done when: Receive path validates storage before accepting/writing.
  - Evidence:
- [ ] Hash verification
  - Done when: Corruption is detected and surfaced.
  - Evidence:
- [/] Retry, cancel, and backoff logic
  - Done when: Long-running operations are always controllable and actionable.
  - Evidence: sender-side transfer actions now expose upload start, cancel, and retry semantics through `TransferBatchActionController` and `FirebaseStorageTransferEngine`; automated backoff and receiver-side control are still pending.
- [ ] Persistence and reconciliation
  - Done when: Backgrounding, rotation, and process death do not lose state silently.
  - Evidence:

### 6.7 Docs, QA, And Submission
- [ ] Real-device test matrix filled
  - Done when: Android phone and iPhone results are recorded.
  - Evidence:
- [ ] README completed
  - Done when: Setup, architecture, tradeoffs, handled cases, and known limitations are honest and complete.
  - Evidence:
- [ ] Walkthrough video scripted and recorded
  - Done when: Happy path plus at least two failures are shown on camera.
  - Evidence:
- [ ] Submission package assembled
  - Done when: APK, iOS instructions/build, source, README, `.env.example`, and video are in Drive.
  - Evidence:

## 7. Device And Test Matrix
- Android physical device:
- Android OS version:
- iPhone physical device:
- iOS version:
- Android emulator:
- Test date:
- Last successful Android -> iPhone run:
- Last successful iPhone -> Android run:
- Last successful background recovery run on Android:
- Last successful background recovery run on iPhone:
- Known platform-specific issues:

## 8. Risk Register
- Risk:
  - Impact:
  - Mitigation:
  - Owner:
  - Status:
- Risk: Firebase and Cloud Run setup may consume more time than the local app foundation.
  - Impact: M1 and M2 could slip if backend contracts are left ambiguous.
  - Mitigation: Keep client contracts fixed, wire anonymous auth/code reservation first, and defer non-critical polish.
  - Owner: Piyush
  - Status: Open
- Risk: Runtime-configured Firebase may behave differently on Android and iPhone if platform app IDs or bundle identifiers are wrong.
  - Impact: Identity registration and recipient lookup can appear implemented in code but fail on-device.
  - Mitigation: Validate Android and iPhone bootstrap separately with real credentials before moving on to transfer work.
  - Owner: Piyush
  - Status: Open
- Risk:
  - Impact:
  - Mitigation:
  - Owner:
  - Status:
- Risk:
  - Impact:
  - Mitigation:
  - Owner:
  - Status:

## 9. Decision Log
- Date: 2026-04-19
  - Decision: Build the client foundation around typed domain contracts and local anonymous identity before Firebase/relay integration.
  - Why: This locks the system boundaries early and gives the backend and native layers stable interfaces to target.
  - Tradeoff: End-to-end transfer is not available yet even though the app shell is now production-grade.
- Date: 2026-04-19
  - Decision: Initialize Firebase from explicit runtime defines instead of checked-in platform secret files.
  - Why: This keeps secrets out of the repo and makes Android+iPhone setup reproducible without generated local files.
  - Tradeoff: Real device verification now depends on supplying correct platform-specific runtime values before backend-backed flows can be exercised.
- Date: 2026-04-19
  - Decision: Use `file_picker` for the core sender-drafting slice and keep native picker work for the bonus track.
  - Why: The assessment explicitly rewards rough but real progress, and the core weighted milestone is end-to-end transfer rather than native picker polish.
  - Tradeoff: The picker path now needs an honest README note because it is intentionally not the bonus-native implementation.
- Date: 2026-04-19
  - Decision: Use Firestore transfer documents as the control-plane source of truth before adding upload/download bytes.
  - Why: This unlocks cross-device inbox discovery, accept/reject semantics, and shared status transitions without waiting for the relay data plane.
  - Tradeoff: Reviewers can now see transfers appear remotely, but actual file movement and progress remain incomplete until the relay/upload slice lands.
- Date: 2026-04-19
  - Decision: Use direct Firebase Storage upload as the first real data-plane slice before introducing a Cloud Run resumable relay.
  - Why: This gets actual bytes moving and shared sender/recipient progress visible quickly while preserving a clear seam for a later relay/native background upgrade.
  - Tradeoff: Current retry behavior restarts the incomplete file rather than resuming true chunk offsets, so transport hardening is still required.

## 10. Session Log
### Session 2026-04-19 16:13
- Planned work: Scaffold the Flutter codebase and replace the default template with a production-grade foundation.
- Completed work: Created the app shell, routing, theme, secure local identity provisioning, typed transfer/recipient contracts, Pigeon bridge scaffold, README baseline, and `.env.example`.
- Evidence added: `flutter analyze` clean; `flutter test` passed; dashboard/profile/send/inbox routes present; tracker and README updated.
- New blocker: Firebase, FCM, Firestore code reservation, and relay deployment are still pending.
- Next step: Implement Firebase anonymous auth, short-code reservation/lookup, and the first real send/inbox backend path.

### Session 2026-04-19 16:41
- Planned work: Add Firebase bootstrap, hybrid identity registration, and recipient lookup without breaking the foundation architecture.
- Completed work: Added Firebase runtime configuration, bootstrap service, hybrid local+remote identity repository, Firestore code reservation logic, and recipient lookup UI/controller.
- Evidence added: `flutter analyze` clean; `flutter test` passed; `.env.example` and README updated with Firebase runtime keys.
- New blocker: Real Firebase credentials and physical-device validation are still required before the addressing flow can be marked fully complete.
- Next step: Configure a live Firebase project, validate registration and lookup on Android+iPhone, then start the first real transfer draft flow.

### Session 2026-04-19 16:46
- Planned work: Harden the addressing slice with user-facing actions and tests for the new lookup rules.
- Completed work: Added copy-code and refresh-registration actions in profile, plus controller tests for malformed codes, self-send blocking, and missing-recipient messaging.
- Evidence added: `flutter analyze` clean; `flutter test` passed with the new recipient lookup controller tests.
- New blocker: Backend-backed registration and lookup still need real Firebase credentials and device verification.
- Next step: Configure Firebase values locally and validate Android+iPhone registration plus lookup before building transfer drafts.

### Session 2026-04-19 18:55
- Planned work: Implement the first `M2` slice by allowing the sender to pick files, validate them, and create a local transfer draft before any transport code is added.
- Completed work: Added `file_picker`, a transfer file-selector abstraction, MIME inference, draft validation, an in-memory transfer repository, a draft-composer controller, send-screen file selection/UI, and outgoing draft visibility/cancellation.
- Evidence added: `flutter analyze` clean; `flutter test` passed with new transfer-draft controller and validator coverage.
- New blocker: The send flow now stops at local draft creation because upload/download, relay transport, and recipient-side realtime delivery are not implemented yet.
- Next step: Build the next `M2` slice by writing transfer records remotely and connecting the first real upload initiation path on top of the new draft queue.

### Session 2026-04-19 19:08
- Planned work: Replace the inbox placeholder with a real shared transfer feed and make sender-created drafts become remote transfer records when Firebase is configured.
- Completed work: Added Firestore-backed transfer creation/watch logic, a hybrid transfer repository with local fallback, recipient-aware transfer creation, live inbox rendering, and accept/reject batch actions.
- Evidence added: `flutter analyze` clean; `flutter test` passed with new recipient-action controller coverage and the existing draft tests updated for the new repository contract.
- New blocker: Actual file bytes still do not upload/download, and Firebase-backed behavior still needs live-project/device validation.
- Next step: Connect the first upload initiation path and sender/recipient progress updates on top of the new shared transfer records.

### Session 2026-04-19 19:20
- Planned work: Refresh the tracker so the remaining execution order matches the actual repo state after the Firestore-backed transfer/inbox slice.
- Completed work: Expanded the top-level left-to-do summary, added an ordered remaining-work checklist, and updated partial statuses/evidence for the unfinished transfer, relay, and edge-case work.
- Evidence added: `PROJECT_TRACKER.md` now reflects the current state of the codebase and the remaining execution order from Firebase validation through submission packaging.
- New blocker: None beyond the already tracked transport/data-plane gap and live Firebase/device validation gap.
- Next step: Implement upload initiation and shared sender/recipient progress on top of the existing transfer records.

### Session 2026-04-19 19:42
- Planned work: Connect the first real sender upload path to the Firestore-backed transfer records and surface shared progress on both sender and recipient screens.
- Completed work: Added a remote-context resolver, extended the transfer repository contract, implemented `FirebaseStorageTransferEngine`, preserved sender-local source metadata for remote batches, wired upload start/cancel actions, and rendered shared per-file plus aggregate upload progress in the send and inbox screens.
- Evidence added: `flutter analyze` clean; `flutter test` passed; `TransferProgressSummary` is now used by both send/inbox; outgoing uploads now persist progress through `FirestoreTransferRemoteDataSource.updateOutgoingTransferBatch`.
- New blocker: Receiver download/save, Storage/Firestore rules, live Firebase/device validation, and stronger resumable transport behavior are still pending.
- Next step: Validate the current upload path on configured devices, then build recipient-side download/save and the remaining starred transport edge cases.

## 11. Final Submission Checklist
- [ ] Signed debug APK tested on clean Android device
  - Evidence:
- [ ] iPhone build path verified
  - Evidence:
- [ ] Source repo or zip ready
  - Evidence:
- [ ] `.env.example` included and secrets excluded
  - Evidence:
- [ ] README finalized
  - Evidence:
- [ ] Architecture diagram included in README
  - Evidence:
- [ ] AI tool usage disclosed honestly
  - Evidence:
- [ ] Video walkthrough recorded
  - Evidence:
- [ ] Drive folder assembled and share settings checked
  - Evidence:
