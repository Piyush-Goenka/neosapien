# NeoSapien

Cross-device file sharing app for the NeoSapien Mobile Developer Intern Assessment.

## Current Status

- Milestone: `M0 Foundation`
- Platforms: `Android + iPhone`
- Architecture: `Flutter + Riverpod + GoRouter + local secure storage`
- Bonus track: `Pigeon` platform bridge for background transfers on Android and iOS

## Foundation Implemented

- Production app shell with feature-first module boundaries
- Strict analyzer configuration and baseline project hygiene
- Typed identity, recipient, and transfer domain models
- Hybrid identity provisioning: local fallback plus Firebase anonymous auth and Firestore-backed code registration when configured
- Routed dashboard, send, inbox, and profile surfaces
- Pigeon contract scaffold for native transfer/background work
- Recipient lookup flow with fast invalid-code handling and Firestore lookup plumbing

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
- `firebase_storage` and `firebase_messaging` are added now to keep the control plane aligned with the assessment architecture, with transfer and notification wiring next.

## Pigeon Code Generation

```bash
dart run pigeon --input pigeons/native_transfer_bridge.dart
```

## Next Implementation Steps

- Finish Firebase code reservation/lookup end to end on real devices
- Replace placeholder send/inbox flows with real transfer orchestration
- Add Cloud Run resumable relay integration
- Implement background transfers through the Pigeon bridge on Android and iOS
