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
- Anonymous local identity provisioning with an unambiguous code format
- Routed dashboard, send, inbox, and profile surfaces
- Pigeon contract scaffold for native transfer/background work

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
     --dart-define=TRANSFER_TTL_HOURS=24
   ```

## Pigeon Code Generation

```bash
dart run pigeon --input pigeons/native_transfer_bridge.dart
```

## Next Implementation Steps

- Wire Firebase anonymous auth, Firestore code reservation, and FCM
- Replace placeholder send/inbox flows with real transfer orchestration
- Add Cloud Run resumable relay integration
- Implement background transfers through the Pigeon bridge on Android and iOS
