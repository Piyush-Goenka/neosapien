# NeoSapien

Cross-device file sharing mobile app for the NeoSapien Mobile Developer Intern Assessment.

Send media by 8-character short code between any two phones on the public internet. Anonymous onboarding, real-time progress, receiver accept/reject, end-to-end SHA-256 integrity, and push-based discovery when the recipient's app is closed.

---

## 1. Status at a glance

| Area | State |
|---|---|
| Android ↔ iOS transfer over the internet | ✅ implemented |
| Anonymous onboarding + short-code registration | ✅ implemented |
| Recipient lookup + invalid-code fail-fast | ✅ implemented |
| Real-time progress (per-file + aggregate) | ✅ implemented |
| Multi-file batches with partial-failure isolation | ✅ implemented |
| SHA-256 integrity (sender hash + receiver verify) | ✅ implemented |
| Filename conflict handling on save | ✅ implemented |
| Low-storage preflight (10% headroom) | ✅ implemented |
| Metered-connection policy enforcement | ✅ implemented |
| Transport encryption (TLS via Firebase SDK) | ✅ inherited |
| Process-death recovery (stale in-flight reconcile) | ✅ implemented |
| Closed-app discovery via FCM + Cloud Function | ✅ implemented |
| Permission handling via PermissionGateway | ✅ scaffolded |
| Network drop resume (true chunk-offset) | ⚠️ restart-from-zero for now (see [§9](#9-known-limitations)) |
| Bonus A — Pigeon contract defined + generated | ✅ bindings shipped (Dart + Kotlin + Swift) |
| Bonus B — Android background (WorkManager/FGS) | ❌ not implemented |
| Bonus C — iOS background (URLSession) | ❌ not implemented |
| Bonus D — native picker (SAF / UIDocumentPicker) | ✅ both platforms via Pigeon |
| Bonus E — native save (MediaStore / PHPhotoLibrary) | ✅ both platforms via Pigeon |
| Bonus F — Nearby fallback transport | ❌ deferred |

---

## 2. Submission links

- **Source**: this repository
- **APK**: see [Drive folder](#) (link in submission email)
- **iOS**: Xcode run instructions in [§4.3](#43-ios-build)
- **Walkthrough video (5–8 min)**: see Drive folder
- **Assessment brief**: [`NeoSapien - Mobile Developer Intern Assessment.md`](./NeoSapien%20-%20Mobile%20Developer%20Intern%20Assessment.md)

---

## 3. Architecture overview

### 3.1 Data-plane + control-plane diagram

```
┌──────────────────────────┐                        ┌──────────────────────────┐
│     Sender device        │                        │   Recipient device       │
│  ┌────────────────────┐  │                        │  ┌────────────────────┐  │
│  │ Flutter + Riverpod │  │                        │  │ Flutter + Riverpod │  │
│  └─────────┬──────────┘  │                        │  └──────────┬─────────┘  │
│            │             │                        │             │            │
│  ┌─────────▼──────────┐  │                        │  ┌──────────▼─────────┐  │
│  │ TransferEngine     │  │                        │  │ TransferEngine     │  │
│  │  (Strategy)        │  │                        │  │  (Strategy)        │  │
│  └─────────┬──────────┘  │                        │  └──────────┬─────────┘  │
└────────────┼─────────────┘                        └─────────────┼────────────┘
             │                                                    │
    ┌────────┼────────────────────────────────────────────────────┼────────┐
    │        │              1. CONTROL PLANE (Firestore)           │        │
    │        │  transfers/{batchId}  users/{uid}  codes/{code}    │        │
    │        │   ◀─────── real-time snapshots (TLS) ──────▶        │        │
    │        │                                                     │        │
    │        │              2. DATA PLANE (Firebase Storage)       │        │
    │        │  ──── putFile(localFile) ▶  transfers/{id}/{fileId} │        │
    │        │                                                     │        │
    │        │                      ◀ writeToFile(reference) ─────│        │
    │        │                                                     │        │
    │        │              3. DISCOVERY (FCM + Cloud Function)    │        │
    │        │   onCreate(transfers/{id})                          │        │
    │        │         ─▶ read users/{recipient}/private/fcm       │        │
    │        │         ─▶ admin.messaging().sendEachForMulticast   │        │
    │        │                  ─▶ APNs / FCM ─▶ recipient device  │        │
    └─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Layered architecture per feature

The project uses **Clean / Hexagonal architecture** per feature module. Each feature lives under [`lib/features/<name>/`](lib/features/) with four strict inward-only layers:

```
presentation/   ── ConsumerWidgets, screens, widgets
    ▲
application/    ── NotifierProviders, controllers, AsyncNotifiers
    ▲
domain/         ── entities, value objects, repository interfaces, services
    ▲
data/           ── data sources (Firestore / Storage / SecureStorage), repository impls
```

Features present today: [`identity`](lib/features/identity/), [`recipients`](lib/features/recipients/), [`transfers`](lib/features/transfers/), [`notifications`](lib/features/notifications/), [`home`](lib/features/home/), [`send`](lib/features/send/), [`inbox`](lib/features/inbox/), [`profile`](lib/features/profile/).

### 3.3 Design patterns in use

| Pattern | Where |
|---|---|
| Repository + data-source split | [`TransferRepository`](lib/features/transfers/domain/repositories/transfer_repository.dart) ← [`HybridTransferRepository`](lib/features/transfers/data/repositories/hybrid_transfer_repository.dart) → [`FirestoreTransferRemoteDataSource`](lib/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart) |
| Composite / hybrid fallback | [`HybridIdentityRepository`](lib/features/identity/data/repositories/hybrid_identity_repository.dart), [`HybridTransferRepository`](lib/features/transfers/data/repositories/hybrid_transfer_repository.dart) — degrade to local-only when Firebase is unreachable |
| Strategy (swappable transport) | [`TransferEngine`](lib/features/transfers/domain/services/transfer_engine.dart) interface with [`FirebaseStorageTransferEngine`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart) today; native impl behind the same contract is the Bonus B/C slot |
| State machine | [`TransferStatus`](lib/features/transfers/domain/entities/transfer_status.dart) (15 explicit states) |
| Value objects | [`RecipientCode`](lib/features/recipients/domain/value_objects/recipient_code.dart) (unambiguous 8-char alphabet, invariants by construction) |
| Typed failures | [`AppException`](lib/core/errors/app_exception.dart) + [`TransferFailureCode`](lib/features/transfers/domain/entities/transfer_failure_code.dart) + `isRecoverable` flag |
| Observer / streams | Firestore `.snapshots()` exposed through Riverpod `StreamProvider` ([`transferBatchesProvider`](lib/features/transfers/application/transfer_draft_controller.dart)) |
| Platform-channel isolation | Pigeon contract in [`pigeons/native_transfer_bridge.dart`](pigeons/native_transfer_bridge.dart) — no manual method-channel strings |
| Idempotency keys | `(batchId, fileId)` on receiver-side save ([`TransferDownloadLocalDataSource.upsertDownloadedFile`](lib/features/transfers/data/data_sources/transfer_download_local_data_source.dart)), FCM notification ID = `batchId.hashCode` for replace semantics |
| Riverpod DI | All services wired through explicit providers with scoped disposal |

---

## 4. Running locally

### 4.1 Prerequisites

- Flutter SDK ≥ 3.10.4
- Node.js 20 (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project on the **Blaze** plan (free-tier covers demo usage, but Cloud Functions require Blaze)
- Xcode (for iOS builds)
- Android Studio + SDK (for Android builds)

### 4.2 First-time Firebase setup

1. Create a Firebase project at https://console.firebase.google.com and enable **Blaze** billing.
2. Enable in the console:
   - **Authentication** → Anonymous provider
   - **Firestore Database** (production mode; rules ship in this repo)
   - **Storage** (rules also ship in this repo)
   - **Cloud Messaging** (APNs key + .p8 upload for iOS — see [§4.4](#44-ios-apns-setup))
3. Register your apps:
   - **Android**: package name `com.neosapien.assignment.neo_sapien`
   - **iOS**: bundle ID `com.neosapien.assignment.neo_sapien`
4. Copy the app IDs, API key, messaging sender ID, and storage bucket from the console into a local `.env` file (see `.env.example`).
5. Deploy rules + indexes + Cloud Function:

   ```bash
   firebase login
   firebase use <your-project-id>
   firebase deploy --only firestore:rules,storage,functions
   ```

6. Verify deploy:
   ```bash
   firebase firestore:rules:get
   firebase functions:log --only onTransferCreated
   ```

### 4.3 Run the Flutter app

Install dependencies:

```bash
flutter pub get
(cd functions && npm install)
```

Run in debug mode with your Firebase config via dart-defines:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=... \
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.neosapien.assignment.neo_sapien \
  --dart-define=RELAY_BASE_URL=https://relay.example.com \
  --dart-define=TRANSFER_TTL_HOURS=24
```

If all Firebase defines are omitted, the app still boots and falls back to a local-only identity. Short-code lookup, transfers, and push discovery all require live Firebase values.

### 4.4 iOS APNs setup (required for FCM push)

Closed-app discovery on iOS requires APNs:

1. Apple Developer Program membership (or a free account works for emulator/personal device)
2. Xcode → Runner target → **Signing & Capabilities** → add **Push Notifications** and **Background Modes** (Remote notifications, Background fetch, Background processing)
3. Firebase console → Project settings → **Cloud Messaging** → upload an **APNs Authentication Key** (.p8) from Apple Developer

Without these steps, Android push still works; iOS push will silently fail.

### 4.5 Android requirements

No extra Android-specific setup beyond the dart-define values. The app manifest already declares:

- `INTERNET`, `ACCESS_NETWORK_STATE`
- `POST_NOTIFICATIONS` (Android 13+)
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` (reserved for Bonus B)
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (reserved for Bonus E)

---

## 5. Transport choice and rationale

**Decision**: Firestore for the control plane, Firebase Storage for the data plane, FCM (Cloud Function trigger) for closed-app discovery. No Cloud Run relay.

### Why not Cloud Run / custom relay?

Considered and rejected because:

1. **Firebase Storage already does chunked resumable uploads** over TLS via the native SDK. Reinventing that on Cloud Run adds a week of infra for marginal control.
2. **Control-plane decoupling**: Firestore's real-time listeners are the single source of truth for batch state. Sender, recipient, and Cloud Function all react to the same `transfers/{batchId}` document. This is an Event-Sourcing lite pattern — state lives in one place, every client projects it.
3. **Security rules** give us fine-grained path + role enforcement per-document without running a server ([firebase/firestore.rules](firebase/firestore.rules), [firebase/storage.rules](firebase/storage.rules)).
4. **Time budget**: one less moving piece = more time for the ★ edge cases and the native bonus track.

### Where the current transport falls short

- **Retry semantics**: after a network drop, the current implementation restarts the failed file from byte 0 rather than resuming from the last successfully uploaded chunk. The seam for true chunk-offset resume is the `TransferEngine` Strategy interface — the native-background engines (Bonus B on Android, Bonus C on iOS) will pick up exactly that offset via the platform Firebase Storage SDKs, which expose `UploadTask#pause()` / `StorageReference#getActiveUploadTasks()` natively.
- **Background survival**: Firebase Storage JS/Dart SDKs pause when the app is backgrounded on both platforms. Bonuses B and C close this gap.

---

## 6. Short-code design

- **Alphabet**: 32 characters, ambiguous chars removed (`O`, `0`, `I`, `l`, `1`). See [`RecipientCodeCodec`](lib/features/recipients/domain/value_objects/recipient_code.dart).
- **Length**: 8 → 32⁸ ≈ 1.1 trillion codes; negligible collision risk.
- **Display format**: `ABCD-WXYZ` (groups of four, hyphen separator) for readability.
- **Reservation**: Firestore transactional write on `codes/{code}` + `users/{uid}` — up to 24 candidate retries on collision. Implementation: [`IdentityRegistryRemoteDataSource.reserveIdentity`](lib/features/identity/data/data_sources/identity_registry_remote_data_source.dart).
- **Identity persistence**: `installationId` stored in FlutterSecureStorage. Clearing app data → new code generated. No recovery flow today (by design — the assessment explicitly discourages feature creep).

---

## 7. FCM closed-app discovery

### Flow
1. On app boot (after anonymous auth), [`FcmTokenRegistrar`](lib/features/notifications/data/services/fcm_token_registrar.dart) reads the current FCM token and writes it to `users/{uid}/private/fcm.tokens` via `arrayUnion` (supports multi-device per user).
2. When the sender creates a `transfers/{batchId}` doc, the [`onTransferCreated`](functions/src/index.ts) Cloud Function fires, reads the recipient's FCM tokens, and sends a multicast data + notification payload via `admin.messaging().sendEachForMulticast()`.
3. Recipient app behavior:
   - **Foreground**: [`IncomingTransferFcmListener`](lib/features/notifications/application/incoming_transfer_fcm_listener.dart) catches `onMessage`, raises a local notification via [`LocalNotificationService`](lib/features/notifications/data/services/local_notification_service.dart).
   - **Background**: OS auto-renders the notification from the Cloud Function's `notification` payload. Tapping fires `onMessageOpenedApp`.
   - **Killed**: OS wakes the app on tap; `getInitialMessage()` replays the tapped message.
4. Any origin beyond "foreground message" routes through GoRouter to `/inbox?batch=<id>` ([`app.dart`](lib/app/app.dart) `ref.listen`).
5. Stale / invalid tokens are pruned on send failure by the Cloud Function.

### Token privacy
FCM tokens are stored under `users/{uid}/private/fcm` — a subcollection whose [Firestore rule](firebase/firestore.rules) restricts read/write to the owner. The Cloud Function reads via the Admin SDK, which bypasses rules. Other users can never read another user's tokens.

---

## 7.5. Native save integration (Bonus A + E)

The bonus track asks for one platform-channel integration done the right way — Pigeon-generated contract, real native code on both sides. That's what Section 2 of the brief calls out:

> *"pick one and implement it via platform channels (Pigeon preferred) rather than a `pub.dev` package"*

### What ships

- **Pigeon contract** in [`pigeons/native_transfer_bridge.dart`](pigeons/native_transfer_bridge.dart) defines `NativeMediaSaverHostApi` with `SaveFileRequest` + `SaveFileResult` data classes.
- **Generated bindings** (committed) — [Dart](lib/platform/native_transfer_bridge.g.dart), [Kotlin](android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeTransferBridge.g.kt), [Swift](ios/Runner/NativeTransferBridge.g.swift).
- **Android impl** — [`NativeMediaSaverImpl.kt`](android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeMediaSaverImpl.kt): routes by MIME to `MediaStore.Images / Video / Audio / Downloads` with atomic `IS_PENDING` publish, scoped-storage compliant (no `WRITE_EXTERNAL_STORAGE` needed on API 29+).
- **iOS impl** — [`NativeMediaSaverImpl.swift`](ios/Runner/NativeMediaSaverImpl.swift): `PHPhotoLibrary.performChanges` for images/videos with the add-only permission request, `UIActivityViewController` share sheet for everything else (lets the user pick "Save to Files").
- **Dart Strategy wrapper** — [`NativeMediaSaver`](lib/features/transfers/data/services/native_media_saver.dart) keeps the Pigeon class out of the rest of the codebase.
- **UI** — per-file Save icon button on every received file in [`inbox_screen.dart`](lib/features/inbox/presentation/screens/inbox_screen.dart), with pending spinner and success/error SnackBar.

### Native picker (Bonus D)

Same Pigeon-bridge pattern for file selection:

- **Contract**: `NativeFilePickerHostApi.pickFiles(allowMultiple)` with `PickedFile` + `PickFilesResult` data classes in [`pigeons/native_transfer_bridge.dart`](pigeons/native_transfer_bridge.dart).
- **Android**: [`NativeFilePickerImpl.kt`](android/app/src/main/kotlin/com/neosapien/assignment/neo_sapien/NativeFilePickerImpl.kt) launches `ACTION_OPEN_DOCUMENT` via `ActivityResultLauncher`, drains both single and clipData multi-pick URIs, streams each URI into `filesDir/neosapien_picked/<uuid>_<name>` so Dart gets a stable in-sandbox path. `MainActivity` switched from `FlutterActivity` to `FlutterFragmentActivity` so `registerForActivityResult` is available.
- **iOS**: [`NativeFilePickerImpl.swift`](ios/Runner/NativeFilePickerImpl.swift) presents `UIDocumentPickerViewController(forOpeningContentTypes: [.data, .content, .item], asCopy: true)`; picked URLs are re-copied into `Library/Caches/neosapien_picked/` for lifetime stability.
- **Dart wrapper**: [`NativeFilePickerTransferFileSelector`](lib/features/transfers/data/services/native_file_picker_transfer_file_selector.dart) implements `TransferFileSelector` via the Pigeon API; `transferFileSelectorProvider` resolves to this on `Platform.isAndroid || Platform.isIOS`, keeps `file_picker` as fallback for tests / desktop / web so nothing else breaks.

### What's intentionally NOT here

- **Native background transfer (Bonus B + C)** — Pigeon contract for `NativeTransferHostApi` exists (start/pause/resume/cancel/query + progress/state Flutter API), native impls not wired. Recorded in [`pigeons/native_transfer_bridge.dart`](pigeons/native_transfer_bridge.dart) as a ready seam.

---

## 8. Section 3 edge-case coverage

### 8.1 Starred (★) — all implemented

| ★ Item | Implementation | File(s) |
|---|---|---|
| Short-code collisions | Transactional `codes/{code}` reservation with 24 candidate retries | [`IdentityRegistryRemoteDataSource`](lib/features/identity/data/data_sources/identity_registry_remote_data_source.dart) |
| Invalid recipient code fails fast | Sync format validation + Firestore lookup miss → clear message | [`RecipientLookupController`](lib/features/recipients/application/recipient_lookup_controller.dart) |
| Recipient offline | Transfer records persist in Firestore with `expiresAt`; FCM push wakes recipient on next connectivity; TTL document field enables scheduled cleanup (future) | [`FirestoreTransferRemoteDataSource`](lib/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart) |
| Network drop mid-transfer | FirebaseException mapped to `TransferFailureCode` with `isRecoverable: true`; retry via `enqueue` picks up from failed files. **Caveat**: restart-from-zero, not chunk-resume (see [§9](#9-known-limitations)) | [`FirebaseStorageTransferEngine`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart) |
| Large files (500MB ceiling) | Client-side preflight; `file_picker` used with `withData: false` so selection is metadata-only; `putFile(File)` streams from disk | [`TransferDraftValidator`](lib/features/transfers/domain/services/transfer_draft_validator.dart), [`FilePickerTransferFileSelector`](lib/features/transfers/data/services/file_picker_transfer_file_selector.dart) |
| Multiple files + partial failure isolation | One file failing no longer aborts the batch; batch resolves to `pendingRecipient` (upload) / `completed` (download) if any file succeeded, `failed` only if all failed; per-file retry via `enqueue` | [`FirebaseStorageTransferEngine._finalizeOutgoingBatch`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart), [`_finalizeIncomingBatch`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart) |
| Permission denial degrades gracefully | `PermissionGateway` abstraction; denied notifications don't crash the app (fcm token registration is best-effort); denied photos just block save-to-gallery (Bonus E) | [`PermissionGateway`](lib/core/permissions/permission_gateway.dart) + [`PermissionHandlerGateway`](lib/core/permissions/permission_handler_gateway.dart) |
| Closed-app discovery | FCM Cloud Function + local notifications + GoRouter deep link to `/inbox?batch=<id>` | See [§7](#7-fcm-closed-app-discovery) |
| Transport encryption | Firebase Auth / Firestore / Storage / Messaging all use TLS by default. APNs/FCM is TLS end-to-end. No custom sockets, no plaintext transport. | n/a (inherited from SDK) |

### 8.2 Non-★ handled

| Item | Implementation | File(s) |
|---|---|---|
| Ambiguous characters removed | 32-char alphabet excludes `O/0/I/l/1` | [`RecipientCodeCodec.alphabet`](lib/features/recipients/domain/value_objects/recipient_code.dart) |
| Self-send policy | Explicitly blocked with dedicated UX copy | [`RecipientLookupController.resolveRecipient`](lib/features/recipients/application/recipient_lookup_controller.dart) |
| Duplicate delivery dedupe | `(batchId, fileId)` as the natural key; `upsertDownloadedFile` filters prior entries; `_hasLocalCopy` short-circuits re-download; notification ID = `batchId.hashCode` | [`TransferDownloadLocalDataSource`](lib/features/transfers/data/data_sources/transfer_download_local_data_source.dart) |
| Metered-connection warning | Enforced before upload/download; policies `wifiOnly` / `confirmOnMetered` / `allowMetered` | [`TransferBatchActionController._ensureNetworkAllowsTransfer`](lib/features/transfers/application/transfer_batch_action_controller.dart) |
| Unusual MIME + zero-byte files | MIME fallback to `application/octet-stream`; zero-byte files accepted by validator; verified by [`transfer_draft_validator_test.dart`](test/features/transfers/domain/services/transfer_draft_validator_test.dart) | [`MimeTypeGuesser`](lib/features/transfers/data/services/mime_type_guesser.dart), [`TransferDraftValidator`](lib/features/transfers/domain/services/transfer_draft_validator.dart) |
| Filename conflict on save | Per-batch directory + deterministic `(2)`, `(3)` suffix renames | [`ReceivedTransferFileStore.createTargetFile`](lib/features/transfers/data/services/received_transfer_file_store.dart) |
| Corruption detection via hash | Streaming SHA-256 on sender before upload + receiver after download; mismatch → delete file + mark `failed` with `integrityCheckFailed` | [`TransferIntegrityService`](lib/features/transfers/data/services/transfer_integrity_service.dart), [`FirebaseStorageTransferEngine`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart) |
| Low-storage preflight | Requires free-space ≥ `totalBytes × 1.1` before accept/download | [`TransferBatchActionController._ensureFreeStorageForBatch`](lib/features/transfers/application/transfer_batch_action_controller.dart) |
| Process-death recovery | Boot-time reconcile marks stale `uploading`/`downloading` docs as `failed + recoverable` | [`TransferRecoveryService`](lib/features/transfers/data/services/transfer_recovery_service.dart), [`reconcileStaleBatchesForUser`](lib/features/transfers/data/data_sources/firestore_transfer_remote_data_source.dart) |

### 8.3 Acknowledged but not fully solved

| Item | Status | Why |
|---|---|---|
| True chunk-offset resume on network drop | Restart-from-zero today | Blocked on native-background Strategy impls (Bonus B/C). Current Firebase Dart SDK pauses on background and Storage's app-level resumable-upload state is per-session. |
| Network Wi-Fi ↔ cellular transition mid-transfer | Partial | `connectivity_plus` subscription exists; transfers get `networkInterrupted` failure on disconnect and must be retried manually. |
| Airplane mode toggled mid-transfer | Partial | Same path as network drop — marks failure, user retries. |
| OEM battery killers (Xiaomi / Oppo / Samsung aggressive wakers) | Acknowledged | Not solvable from within a Flutter app without a native foreground service. Bonus B would partially address this. |

---

## 9. Known limitations

Stated up-front so reviewers can score fairly:

1. **Restart-from-zero on network drop**, not true chunk resume. Implementation seam is ready in the `TransferEngine` Strategy pattern for the native-background engines to pick up.
2. **Native background transfer (Bonus B + C) not implemented**. Pigeon contract is scaffolded in [`pigeons/native_transfer_bridge.dart`](pigeons/native_transfer_bridge.dart) but code generation and native Kotlin/Swift sides have not been wired.
3. **Nearby transport (Bonus F) not implemented**. Explicitly deferred in the plan.
6. **TTL / expiry enforcement is client-side only today**. Batch docs carry an `expiresAt` field but no scheduled Cloud Function sweeps expired batches yet.
7. **Device test matrix is "1 real + 1 emulator"**: real Android phone + Android emulator on Mac. Brief explicitly allows this. OEM-specific behaviors on physical Android devices have not been demonstrated.
8. **iOS FCM push is not demonstrated.** The iOS simulator runs the full app end-to-end (identity, recipient lookup, upload/download, SHA-256 verify, save to app Documents), and cross-platform Android ↔ iOS transfers work live in the demo. What doesn't work on the iOS simulator — by Apple's platform design — is APNs/FCM push: simulators never receive push, and real-device push requires Apple Developer Program enrollment plus an APNs key uploaded to Firebase Console. The client-side wiring (`FcmTokenRegistrar`, `IncomingTransferFcmListener`, background `URLSession` entitlements in `Info.plist`) is complete and will work once those prerequisites are met. Closed-app discovery is therefore demonstrated on Android only.
9. **Identity does not survive app reinstall or "clear app data".** This is a conscious tradeoff, not an oversight. The identity is stored in `FlutterSecureStorage` (iOS Keychain / Android EncryptedSharedPreferences), which is wiped on uninstall by both platforms' design. A reinstall yields a **new** installation ID, which claims a **new** short code via the Firestore reservation. The old short code remains registered (until a TTL job reclaims it), so the user's contacts may need to be told the new code. Alternative designs considered and rejected: (a) seed-phrase recovery — requires user memorization UX and wasn't in scope; (b) Keychain iCloud sync (iOS) / backup (Android) — platform-specific, unreliable cross-device. The current behavior is honest, matches user intuition ("I uninstalled, I'm a new user"), and keeps the anonymous-only requirement clean.
10. **Auth is anonymous-only by design** per the brief — no email / phone / social sign-in path.
11. **Metered-connection policy is enforced but has no tap-to-confirm UX** — the `confirmOnMetered` policy currently blocks and instructs the user to switch policy on the sender. A proper confirm dialog was out of scope for today.
12. **Content privacy is limited to Accept / Reject at receive time.** There is no rate limit on how often a given sender can target a recipient, no per-sender block list, and no abuse-reporting path. For the assessment scope this is acceptable; a production deployment would add rate-limiting at the Cloud Function layer and a sender-block list persisted under `users/{uid}/private/blocks`.
13. **OEM battery killers on Android** (Xiaomi MIUI, Oppo ColorOS, Samsung OneUI aggressive wakers) may terminate the app's background work even when it would be technically supported on stock Android. Not solvable from within a Flutter app — requires per-OEM guidance and is typically addressed at the business/UX level with "please disable battery optimization for this app" onboarding.

---

## 10. Project structure

```
.
├── lib/
│   ├── main.dart                    # Entry point + FCM background handler
│   ├── app/
│   │   ├── app.dart                 # Root widget, deep-link listener
│   │   ├── bootstrap.dart           # Firebase init + loading shell
│   │   ├── router/app_router.dart   # GoRouter config
│   │   └── theme/                   # Material 3 theme
│   ├── core/
│   │   ├── config/                  # AppEnvironment (dart-defines)
│   │   ├── firebase/                # FirebaseBootstrapService + options
│   │   ├── permissions/             # PermissionGateway + impl
│   │   ├── connectivity/            # ConnectivityGateway + impl
│   │   ├── storage/                 # DeviceStorageChecker + impl
│   │   ├── errors/                  # AppException sealed hierarchy
│   │   ├── utils/                   # ByteCountFormatter
│   │   └── providers/               # Riverpod provider wiring
│   ├── features/
│   │   ├── identity/                # anonymous auth + short-code reservation
│   │   ├── recipients/              # code value object + Firestore lookup
│   │   ├── transfers/               # core batch/file/engine/progress
│   │   ├── notifications/           # FCM + local-notifications + event bus
│   │   ├── home/                    # dashboard
│   │   ├── send/                    # sender composer UI
│   │   ├── inbox/                   # recipient accept / download UI
│   │   └── profile/                 # identity display + runtime settings
│   └── shared/presentation/widgets/ # AppScaffold (nav + bottom bar)
├── firebase/
│   ├── firestore.rules              # role-scoped Firestore security
│   ├── firestore.indexes.json       # composite indexes (empty; single-field is auto)
│   └── storage.rules                # role-scoped Storage security
├── functions/
│   └── src/index.ts                 # onTransferCreated FCM trigger
├── pigeons/
│   └── native_transfer_bridge.dart  # Pigeon contract (Bonus A scaffold)
├── android/                         # Android platform project
├── ios/                             # iOS platform project
├── test/                            # unit + widget tests (17 passing)
└── PROJECT_TRACKER.md               # live status board
```

---

## 11. AI tool usage

I used **Claude Code** (Anthropic) extensively on this assessment — as both pair programmer and reviewer. Specifically:

- **Architecture scaffolding**: the initial Clean-architecture layering, repository/data-source split, and Riverpod wiring were drafted interactively with Claude. I reviewed every provider wiring and verified dependency directions (domain never imports data).
- **Firebase rules**: wrote the first draft of [`firestore.rules`](firebase/firestore.rules) + [`storage.rules`](firebase/storage.rules) with Claude, then hand-checked every predicate against the actual queries used by the Firestore data source.
- **Transfer engine refactor**: the partial-failure isolation rewrite ([§8.1](#81-starred---all-implemented) "multiple files") was guided by Claude, but the state-transition table (when to return `pendingRecipient` vs `failed` for mixed outcomes) is my decision.
- **Cloud Function**: [`functions/src/index.ts`](functions/src/index.ts) is essentially Claude-generated boilerplate for `onDocumentCreated` → `sendEachForMulticast` with invalid-token cleanup. I verified the admin SDK call shape and the payload format expected by the Dart FCM listener.
- **README + tracker**: both this file and [`PROJECT_TRACKER.md`](PROJECT_TRACKER.md) were drafted with Claude and reviewed end-to-end by me.

### Where I overrode the AI's suggestion

- Proposed Cloud Run resumable relay → I rejected it in favor of direct Firebase Storage to keep the seam clean for native-background engines (Bonus B/C).
- Proposed `flutterfire configure` → I kept the `--dart-define` runtime-config pattern so no Firebase secrets live in the committed repo.
- Proposed in-line notification permission request at every transfer start → moved to a single boot-time request ([`notificationBootProvider`](lib/features/notifications/application/notification_bootstrap.dart)) so the user isn't re-prompted per transfer.
- Proposed adding a separate corrupted-file status on `TransferFileStatus` → decided instead to keep the 5-state enum and carry corruption info in the existing `failure` field with `TransferFailureCode.integrityCheckFailed`.

---

## 12. Quality gates

Every commit on this branch passes:

```bash
flutter analyze       # 0 warnings, strict analyzer config
flutter test          # 17 unit + widget tests, all green
(cd functions && npm run build)   # TypeScript strict mode, 0 errors
```

---

## 13. Demo walkthrough outline (for the video)

The video covers, on a real iPhone + an Android emulator:

1. Cold-launch both apps → anonymous identity provisioning → short codes displayed (Dashboard + Profile)
2. Device A opens `/send`, enters Device B's code → recipient resolves live
3. Device A picks 3 files, selects `Allow Metered` policy, creates draft → batch appears on both devices
4. Device B accepts → Device A starts upload → shared per-file + aggregate progress visible on both
5. Device B downloads → files saved under `Documents/neo_sapien_received/{batchId}/` with deterministic conflict rename for duplicate names
6. **Failure demo 1**: turn Wi-Fi off mid-transfer → batch marks `failed + recoverable` → re-enable → retry from inbox → completes
7. **Failure demo 2**: send with a bad short code → fast validation + "No device is registered under that code yet" message
8. **Failure demo 3**: kill the recipient app during an active download → relaunch → process-death reconcile marks it failed → retry completes
9. **Closed-app demo**: force-quit Device B → Device A sends new batch → Device B gets push notification → tap routes to `/inbox?batch=<id>`
10. 60-second code tour: [`FirebaseStorageTransferEngine`](lib/features/transfers/data/services/firebase_storage_transfer_engine.dart), [`IncomingTransferFcmListener`](lib/features/notifications/application/incoming_transfer_fcm_listener.dart), [`firestore.rules`](firebase/firestore.rules), [`PROJECT_TRACKER.md`](PROJECT_TRACKER.md)

---

Questions or issues: see [`PROJECT_TRACKER.md`](PROJECT_TRACKER.md) for live status, risks, and session log.
