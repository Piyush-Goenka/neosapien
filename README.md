# NeoSapien

Cross-device file sharing app for the NeoSapien Mobile Developer Intern Assessment.

## Current Status

- Milestone: `M2 Core Transfer Happy Path` (sender upload and shared progress implemented; receiver download/save still pending)
- Platforms: `Android + iPhone`
- Architecture: `Flutter + Riverpod + GoRouter + Firebase control plane + Firebase Storage data plane + local fallback`
- Bonus track: `Pigeon` platform bridge for background transfers on Android and iOS

## Foundation Implemented

- Production app shell with feature-first module boundaries
- Strict analyzer configuration and baseline project hygiene
- Typed identity, recipient, and transfer domain models
- Hybrid identity provisioning: local fallback plus Firebase anonymous auth and Firestore-backed code registration when configured
- Routed dashboard, send, inbox, and profile surfaces
- Pigeon contract scaffold for native transfer/background work
- Recipient lookup flow with fast invalid-code handling and Firestore lookup plumbing
- Sender-side file picking, preflight validation, network policy selection, and local transfer draft creation
- Shared transfer repository with Firestore-backed transfer creation/watch plus local fallback
- Live inbox discovery with recipient accept/reject actions on incoming transfer records
- Firebase Storage-backed sender upload engine with Firestore batch/file progress updates
- Shared per-file and aggregate upload progress rendering in both the sender queue and recipient inbox

## Architecture Snapshot

```text
lib/
  app/
    router/
    theme/
  core/
    config/
    errors/
    providers/
    utils/
  features/
    home/
    identity/
    inbox/
    profile/
    recipients/
    send/
    transfers/
  shared/
    presentation/
```

## Local Run

1. Fetch packages:

   ```bash
   flutter pub get
   ```

2. Run the app:

   ```bash
   flutter run \
     --dart-define=RELAY_BASE_URL=https://relay.example.com \
     --dart-define=TRANSFER_TTL_HOURS=24 \
     --dart-define=FIREBASE_API_KEY=... \
     --dart-define=FIREBASE_PROJECT_ID=... \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_STORAGE_BUCKET=... \
     --dart-define=FIREBASE_ANDROID_APP_ID=... \
     --dart-define=FIREBASE_IOS_APP_ID=... \
     --dart-define=FIREBASE_IOS_BUNDLE_ID=com.neosapien.assignment.neo_sapien
   ```

3. If Firebase defines are omitted, the app still boots and falls back to a local-only identity. Real recipient lookup and server-backed short-code registration require the Firebase values above.

## Firebase Control Plane

- `firebase_core` initializes from explicit `--dart-define` values instead of checked-in secret files.
- `firebase_auth` is used for anonymous device sessions.
- `cloud_firestore` stores `users/{uid}` and `codes/{shortCode}` documents for identity registration and recipient lookup.
- `firebase_storage` is now used for the first real sender-side upload path, while `firebase_messaging` remains planned for closed-app discovery.

## Current Transfer Scope

- `file_picker` is used for the core sender-draft slice so batch composition can move forward before native picker bonus work.
- When Firebase is configured, the app now creates remote transfer records that appear in the recipient inbox without a manual refresh.
- After the recipient accepts, the sender can start a Firebase Storage upload and both sender and recipient see shared per-file plus aggregate upload progress from the same Firestore documents.
- Current retry behavior restarts the incomplete file cleanly after failure; true chunk-resume and background survival are still future slices.
- Recipient download, save-to-device, and completed-history behavior are not implemented yet.
- Draft validation already enforces file-count, per-file, and total batch-size limits without loading file data into memory.
- Native picker integration remains planned as a bonus replacement once the core internet transfer path is stable.

## Pigeon Code Generation

```bash
dart run pigeon --input pigeons/native_transfer_bridge.dart
```

## Next Implementation Steps

- Validate Firebase code reservation, accepted upload start, and shared progress end to end on real devices
- Add recipient download, save-to-device flow, and completed-history state
- Decide whether to keep the current direct Firebase Storage path or replace it with the planned Cloud Run resumable relay for stronger resume semantics
- Add push notifications and closed-app discovery
- Implement background transfers through the Pigeon bridge on Android and iOS
