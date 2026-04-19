# NeoSapien Project Tracker

## 1. Project Snapshot
- Deadline: 2026-04-20 08:00 PM
- Goal: Ship a production-grade cross-device file sharing app that works on a real Android phone and a real iPhone.
- Platforms: Flutter app with full Android + iPhone parity.
- Primary bonus: Pigeon-based background transfer on Android and iOS.
- Secondary bonus: Native picker + native save flow if core is already green.
- Current phase: M1 Identity And Addressing
- Overall status: [/]
- Current focus: Validate the new Firebase bootstrap and Firestore registration flow against a real Firebase project, then finish the identity/addressing milestone on physical devices.
- Next milestone: M1 Identity And Addressing
- Latest blocker: Real Firebase project credentials and device validation are still missing, so the new runtime bootstrap and Firestore flows are implemented but not yet verified end to end.
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
- Foundation validation completed: `flutter analyze` passes and `flutter test` passes after the Firebase/addressing slice.

### Left To Do
- Finish `M0 Foundation` by supplying real Firebase project values, validating Android+iPhone bootstrap, and confirming Firebase plugin setup on both platforms.
- Finish `M1 Identity And Addressing`: validate server-backed short-code reservation on a real Firestore project, confirm collision handling behavior, and complete profile-sharing polish.
- Implement `M2 Core Transfer Happy Path`: real file selection, batch creation, internet upload/download, sender and recipient progress, and cross-device transfer in both directions.
- Implement `M3 Resilience And Starred Cases`: offline recipient handling, network-drop recovery, large-file streaming, multi-file partial failure, permission denial, incoming-while-closed flow, and TLS-backed transport.
- Implement `M4 Native Background Transfer Bonus`: Android foreground service/WorkManager plus iOS background `URLSession` through the Pigeon bridge.
- Implement `M5 Cross-Platform Hardening`: disk-space checks, hash verification, save conflict handling, process-death recovery, network transition handling, and real-device parity validation.
- Finish `M6 Submission Assets`: final README, APK/iPhone build verification, walkthrough video, device matrix, Drive package, and evidence capture.

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
- [ ] Send one or more media files to a short code
  - Done when: Images, video, audio, documents, and arbitrary files can be sent in a single batch.
  - Evidence:
- [ ] Works across distance / internet relay
  - Done when: Transfers do not depend on proximity, LAN, or localhost.
  - Evidence:
- [ ] Real-device proof path
  - Done when: At least one Android phone and one iPhone complete end-to-end tests.
  - Evidence:
- [ ] Real-time progress and final success/failure states
  - Done when: Sender and recipient both see state transitions without manual refresh.
  - Evidence:

### 4.2 Starred Edge Cases
- [/] Short-code collisions handled
  - Done when: Reservation is guaranteed unique or collision retries are transparent.
  - Evidence: `IdentityRegistryRemoteDataSource.reserveIdentity` retries candidate codes and uses Firestore transactions to avoid duplicate claims; still pending live-project verification.
- [/] Invalid recipient code fails fast with clear UI
  - Done when: Sender cannot start upload to a non-existent code.
  - Evidence: `RecipientLookupController` blocks malformed codes immediately and shows a clear "No device is registered under that code yet" message when Firestore lookup misses; covered by `recipient_lookup_controller_test.dart`.
- [ ] Recipient offline behavior implemented
  - Done when: Queued delivery or explicit rejection policy is implemented and documented.
  - Evidence:
- [ ] Network drop mid-transfer handled
  - Done when: Resume, restart, or fail-cleanly policy works and is tested.
  - Evidence:
- [ ] Large files handled without OOM
  - Done when: Hard size ceiling is enforced and near-limit files stream safely.
  - Evidence:
- [ ] Multiple files at once with partial failure isolation
  - Done when: One file can fail without killing the whole batch.
  - Evidence:
- [ ] Permission denial degrades gracefully
  - Done when: Denied storage/photos/notifications does not crash the app.
  - Evidence:
- [ ] Incoming transfer while app is closed is discoverable
  - Done when: Notification/deep-link or equivalent recipient entry path works.
  - Evidence:
- [ ] Transport encryption enforced
  - Done when: HTTPS/TLS is used end to end and documented in README.
  - Evidence:

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
- [ ] Metered connection warning added
  - Done when: Large cellular transfers require an explicit confirmation.
  - Evidence:
- [ ] Unusual MIME and zero-byte files do not crash
  - Done when: `.heic`, `.webp`, `.mov`, extensionless, and empty files are handled.
  - Evidence:
- [ ] Filename conflict policy implemented
  - Done when: Save collisions rename deterministically.
  - Evidence:
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

- [ ] M2 Core Transfer Happy Path
  - Done when: Cross-device upload/download works in both directions with progress and final statuses.
  - Evidence:

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
  - Evidence: Firebase packages added, runtime bootstrap service added, and providers for auth/firestore/storage/messaging now exist; actual project credentials and FCM/runtime verification remain pending.
- [/] Implement unique short-code reservation flow
  - Done when: Collision-safe registration exists.
  - Evidence: `IdentityRegistryRemoteDataSource` implements Firestore-backed `users/{uid}` and `codes/{shortCode}` writes with transaction-based reservation and retry.
- [ ] Deploy resumable relay on Cloud Run
  - Done when: Streaming upload/download and resumption path are available.
  - Evidence:
- [ ] Add TTL expiry, signed access, and server validation
  - Done when: Transfer lifecycle rules are enforced server-side.
  - Evidence:

### 6.3 Flutter Transfer Experience
- [x] Onboarding and profile screen
  - Done when: User can see and share their code.
  - Evidence: dashboard/profile routes render the provisioned local identity and runtime configuration through the new app shell.
- [/] Recipient lookup and send composer
  - Done when: Sender can resolve code and prepare a batch.
  - Evidence: send screen now includes backend-backed recipient lookup with validation, self-send blocking, and missing-recipient messaging; file selection and batch creation are still pending.
- [ ] Sender progress UI
  - Done when: Per-file and aggregate states are visible and actionable.
  - Evidence:
- [ ] Recipient inbox and accept/reject flow
  - Done when: Incoming transfers are visible and can be acted on.
  - Evidence:
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
- [ ] Retry, cancel, and backoff logic
  - Done when: Long-running operations are always controllable and actionable.
  - Evidence:
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
- Date:
  - Decision:
  - Why:
  - Tradeoff:

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
