# NeoSapien — Mobile Developer Intern Assessment

## NeoSapien — Flutter Developer Intern Assessment

- **Timeline:** `20/04/2026 - 08:00 PM`
- **Platform:** Mobile only — Android and/or iOS. Web and desktop submissions will not be evaluated.
- **Stack:** Flutter strongly preferred. Native Android (Kotlin) or iOS (Swift) acceptable. React Native only if you can demonstrate Flutter fluency separately in the follow-up.
- **AI tools (Cursor, Claude Code, Copilot, etc.):** Encouraged. Be ready to defend every architectural decision.

## 1. The Brief

Build a real-time cross-device file sharing mobile app that lets users send media from one phone to another — whether the phones are next to each other or on opposite sides of the world.

### Core requirements

- Mobile-only. Sender and recipient both run on a phone.
- Anonymous onboarding. No email, password, or phone number. Provision an identity locally on first launch.
- Short-code identity. Each user gets a unique human-friendly ID — a 6–8 character alphanumeric code (`A4X9K2`) or word-based handle (`swift-otter-42`). Collision handling is on you.
- Send media to a short code. Given a recipient's code, push one or more media files (images, video, audio, documents, arbitrary binaries). Arrival should be near-real-time when the recipient is online. Define your offline behavior (queue? expire? reject?) and document it.
- Works across distance. Transport must not assume physical proximity — different networks, NATs, countries.
- Works across two real mobile devices. Minimum: Android ↔ Android on two physical devices, or one physical device + one emulator. Single-device demos are not accepted.
- Real-time progress. Both sides see upload/download progress and clear success/failure states.

**On "real-time":** We don't expect WebRTC-grade latency. We do expect that when A sends to B with B's app open, B sees the transfer start within a couple of seconds without manual refresh. WebSockets, FCM data messages + signed URLs, Firestore listeners, Supabase Realtime, self-hosted relay, WebRTC — all valid. Justify your choice.

## 2. Bonus: Platform Channel / Native Integration

Optional but heavily rewarded. NeoSapien's production app bridges Flutter to native code constantly via Pigeon, method channels, and event channels. If you have time after the core flow is solid, pick one and implement it via platform channels (Pigeon preferred) rather than a `pub.dev` package:

1. Native file picker — invoke `ACTION_OPEN_DOCUMENT` (Android) / `UIDocumentPickerViewController` (iOS) directly, stream bytes back to Dart.
2. Save-to-gallery / Downloads — write received media to `MediaStore` (Android 10+) or Photos/Files (iOS), handling scoped-storage quirks yourself.
3. Native share sheet — "Share via…" invoking the OS share intent natively.
4. Background transfer — keep an in-flight transfer alive when backgrounded, using a foreground service (Android) and/or `URLSession` background config (iOS).
5. Nearby transport (highest signal) — detect physically nearby recipients via Wi-Fi Direct, BLE, or local subnet and transfer peer-to-peer, falling back to cloud otherwise. This mirrors what our Neo 1 wearable does.

A rough partial attempt here beats a polished `file_picker` integration. In the README, tell us what you picked, how far you got, and what you'd do with more time.

## 3. Edge Cases to Handle

"Works on the happy path" is the floor. Starred (`★`) items must actually work in your build. The rest you should have defensible answers for in the review.

### Identity & addressing

- `★` Short-code collisions — generation + registration should make this impossible or handle it gracefully.
- `★` Invalid recipient code — sender types a code no one owns. Fail fast with a clear UI message.
- Ambiguous characters — `O` / `0`, `I` / `l` / `1`. Pick your alphabet intentionally.
- Self-send — allow or block? Decide.
- Identity persistence — user clears app data or reinstalls. Same code? New code? Recovery flow? Document the tradeoff.

### Transport & delivery

- `★` Recipient offline — queue with TTL, or reject as unreachable. Either is defensible; pick one.
- `★` Network drops mid-transfer — on reconnect, resume / restart / fail? Chunked resumable uploads is the mature answer.
- Sender kills the app mid-upload — does the upload survive?
- Duplicate delivery — dedupe on the receiver by transfer ID, not filename.
- Metered connections — don't silently burn cellular quota on a 400 MB video. Warn, or require a tap.

### Files & media

- `★` Large files — pick a ceiling (500 MB or 1 GB), enforce it, make anything up to that work without OOM. Stream, don't load into memory.
- `★` Multiple files at once — per-file and aggregate progress. One failure doesn't kill the batch.
- Unusual MIME types — `.heic`, `.webp`, `.mov`, extensionless files. Don't crash.
- Empty / zero-byte files — rare but real.
- Filename conflicts on save — overwrite, rename, prompt?
- Corrupted transfers — verify end-to-end with a hash (SHA-256 or similar).

### Permissions & platform

- `★` Permission denial — user denies storage/notifications/camera. Degrade, don't crash. Android 13+ has granular media permissions; iOS has Limited vs Full photo library.
- Scoped storage (Android 10+) — use `MediaStore` or app-scoped directories, not arbitrary paths.
- OEM battery killers — Xiaomi, Oppo, Samsung, OnePlus kill background work aggressively. Acknowledge this even if you don't fully solve it.
- App killed by OS under memory pressure — state should be recoverable on next launch, or fail cleanly.
- `★` Incoming transfer while app is closed — how does the recipient find out? Push notification with deep link? Silent data message that wakes a worker? Pick an approach.

### Mobile device conditions

- Low device storage — recipient has 200 MB free, sender pushes 500 MB. Check space before accepting; fail with a clear message, not a half-written file.
- Low battery / power-save — Doze and iOS Low Power Mode throttle network and background work. Don't assume a 30-second transfer finishes.
- Network transitions — Wi-Fi ↔ cellular mid-transfer. Does the transfer survive?
- Airplane mode toggled mid-transfer — distinct from flaky network.
- App backgrounded long then foregrounded — stale connections must be detected and re-established.

### Security & privacy

- `★` Transport encryption — TLS at minimum. Mention in README.
- Content privacy — anyone with a code can send files. Rate limiting? Accept-incoming prompt? Block list?
- At-rest encryption on any relay that stores files even briefly.
- Short-code guessability — 4 alphanumeric chars is trivially enumerable. Pick length and alphabet intentionally.

### UX under failure

- Every long-running operation has a cancel affordance.
- Every error surfaces something the user can act on — no `Exception: null`.
- In-progress transfer state survives backgrounding, process death, and rotation.

## 4. Scope Discipline

### Must be real and working

- Anonymous user creation, short-code generation and lookup
- Sender-to-recipient transfer over the internet (not localhost)
- Real-time progress on both ends
- All starred (`★`) edge cases from Section 3

### OK to stub or fake (note in README)

- analytics
- paywalls
- billing
- polished onboarding copy
- cross-platform parity (pick Android or iOS and ship it properly rather than half-shipping both)

### Don't spend time on

- pixel-perfect design
- auth beyond anonymous
- feature creep (messaging, read receipts, group transfers — no)

## 5. Deliverables

Upload to a single Google Drive folder with view access for anyone, then share the link.

### 1. Installable build

- **Android:** signed debug APK, tested on a clean device.
- **iOS:** TestFlight invite (preferred — email `[HIRING_EMAIL]` to add as tester) or unsigned build + Xcode run instructions.
- No emulator-only builds.

### 2. Source code

- Zipped repo in the Drive folder, or a public GitHub link in the README.
- Include `.env.example` (no committed secrets) and setup instructions that work on a fresh clone.

### 3. `README.md` covering

- how to run locally (including backend/relay if any)
- devices and OS versions tested on
- architecture overview (ASCII diagram is fine) — client, transport, relay, storage
- transport choice and rationale
- platform channel bonus if attempted (what, how far, what's next)
- Section 3 edge cases you handled and didn't
- known bugs and limitations (be honest — we grade honesty highly)
- AI tool usage and where you overrode its suggestions

### 4. Video walkthrough (5–8 min)

- Two real devices on screen (or one real + one emulator, not two emulators)
- User creation on Device A and B
- Code exchange
- Successful A → B transfer with both screens visible
- At least two deliberate failure modes triggered and handled (Wi-Fi off mid-transfer, app backgrounded during upload, bad code, huge file, app-kill-and-reopen — whatever you implemented)
- 60-second code tour

If you have zero physical phones, reach out — we'll figure something out.

## 6. Evaluation (in order of weight)

1. Does it work end-to-end on two real mobile devices? If A can't send to B, nothing else matters.
2. How does it behave under failure? Network off, bad code, huge file, permission denied, app backgrounded.
3. Architecture and code quality — clear UI / transport / state separation? Errors handled or swallowed? Extensible?
4. README honesty — candidates who clearly document what they skipped consistently outperform those who claim everything works.
5. Walkthrough video — can you explain your own code and defend your decisions?
6. Bonus: platform channel work — counts in your favor; its absence won't sink an otherwise strong submission.

## 7. Logistics

- **Questions:** reply to the email you received this from. We'd rather answer than have you guess wrong for three days.
- **Submission:** Drive link by the deadline in your offer email. Late is fine if you tell us in advance; silent late is not.
- **AI tools:** use them. Be ready to explain your code without them.
- Don't publish this brief. We rotate it periodically.

Good luck.

— NeoSapien Engineering
