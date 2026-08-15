# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Notifly is an iOS SwiftUI app for allied-health clinicians (OT/speech-path) that records a therapy session, transcribes it on-device, and generates a clinical session note (SOAP, DAP, or goal-focused format) using Apple's on-device Foundation Models. Everything — transcription and note generation — runs on-device, no backend or network dependency.

The Xcode project (`Notifly-app.xcodeproj`) and its source (`Notifly-app/`) both live inside this repo root, i.e. source is at `Notifly-app/Notifly-app/`.

## Build

```bash
xcodebuild -project Notifly-app.xcodeproj -scheme Notifly-app -configuration Debug build
```

Add `-destination 'platform=iOS Simulator,name=<device>'` to target a specific simulator. There is a single scheme (`Notifly-app`) and no test target — `xcodebuild test` has nothing to run until one is added.

Deployment target is iOS 26.4; the app depends on iOS 26 on-device APIs (`FoundationModels`, `Speech`/`SpeechAnalyzer`). No third-party dependencies — no SPM packages, CocoaPods, or Carthage; only first-party frameworks (SwiftUI, SwiftData, Speech, AVFoundation, FoundationModels).

## Architecture

**Persistence**: SwiftData. `Notifly_appApp.swift` builds the `ModelContainer` for `[Client, Goal, GoalStatusEntry, SessionNote]` at `applicationSupportDirectory/Notifly.store`. If the container fails to init (e.g. schema mismatch during development), it deletes the store files and retries once before crashing — expect data loss across schema changes rather than migrations. The app root scene is `HomeView()` directly; `ContentView.swift` is vestigial and unused.

**Models** (`Models/`) — SwiftData `@Model` entities:
- `Client` → has-many `SessionNote` (nullify on delete) and `Goal` (cascade delete)
- `Goal` → belongs to `Client`, has-many `GoalStatusEntry` (cascade); status is a raw string decoded via the `GoalStatus` enum
- `GoalStatusEntry` — audit log of goal status changes, tracks `source` (manual / accepted-suggestion / dismissed-suggestion / edited)
- `SessionNote` — the generated note; holds SOAP fields, DAP fields, or goal-focused `goalCards` (JSON-encoded in a `goalsJSON` string column) depending on `noteFormat`

**Services** (`Services/`) — the core domain logic:
- `SpeechRecognizer` (`@Observable @MainActor`) — records to a temp WAV via `AVAudioRecorder`, transcribes on-device with `SpeechAnalyzer`/`SpeechTranscriber`, biased with a hand-tuned list of clinical (OT/speech-path) vocabulary. Exposes `transcript`, `isRecording`, `isTranscribing`, `inputLevel`.
- `NoteGenerationService` — static functions wrapping `FoundationModels` (`LanguageModelSession`, `@Generable`/`@Guide` structured output). Deliberately splits generation into multiple small, single-purpose model passes (e.g. factual pass → interpretive pass; or goal-anchor pass → per-goal write-up → leftover-observations pass) rather than one large prompt, with deterministic string post-processing (e.g. transcription-error fixes) done in code rather than via the model. Errors map to a clinician-facing `NoteGenerationError` enum (device ineligible, Apple Intelligence off, model downloading, transcript too long, content flagged, etc).
- `generateSOAP`/`generateDAP`/`generateGoalFocused` accept an optional `clientContext: ClientContext?`, but `ClientContext`/`GoalContext` are not defined anywhere in the repo and the only caller (`ReviewNoteView`) never passes one — this integration point is unfinished.

**Views** (`Views/`) — no ViewModel layer; views talk directly to SwiftData (`@Query`, `@Environment(\.modelContext)`) and call `Services` directly. State is `@State`/`@Bindable`/`@AppStorage`; `@Bindable` is used to edit SwiftData models in place (e.g. `ClientDetailView`, `NoteDetailView`). Navigation is `NavigationStack` + `NavigationLink`, with `HomeView` owning a `NavigationPath` for programmatic pushes.

Primary flow: `NewSessionView` (pick client/format/tone) → `RecordingView` (uses `SpeechRecognizer`) → `ReviewNoteView` (calls `NoteGenerationService`, saves a `SessionNote`) → `NoteDetailView`. Client/goal management: `ClientListView` / `ClientDetailView` / `ClientEditorView` / `GoalDetailView` / `GoalEditorView` / `GoalStatusChangeSheet`. `HomeView` is the app root: groups `SessionNote`s by `sessionID`, buckets into Today/This Week/Earlier, plus a client search bar and recent-clients carousel.

## Permissions

Microphone and speech-recognition usage descriptions are set directly on the Xcode target (`INFOPLIST_KEY_NSMicrophoneUsageDescription`, `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription`) rather than via a standalone `Info.plist` — the project uses `GENERATE_INFOPLIST_FILE`.
