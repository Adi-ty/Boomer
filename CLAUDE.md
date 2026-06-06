# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Boomer** is a macOS virtual desktop pet — a Rive-animated companion that lives on the desktop, reacts to system events (downloads, installs, typing, coding-agent completion), and offers notes/reminders plus on-device AI. Onboarding picks a species: **Boomer** (dog) or **Buttons** (cat); the other is unlockable.

- **Requirements:** macOS 26+ (Tahoe), Apple Silicon, Xcode 26 / Swift 6.3+.
- **Distribution:** direct notarized download, **non-sandboxed** (App Store sandbox would break typing capture, window tracking, and file watching).

## Commands

The Xcode project is generated from `project.yml` via XcodeGen — never hand-edit `Boomer.xcodeproj` (it is git-ignored and regenerated).

```bash
make bootstrap   # install toolchain deps (xcodegen, swiftlint, swiftformat) + generate
make generate    # xcodegen generate -> Boomer.xcodeproj
make build       # xcodebuild -scheme Boomer -configuration Debug build
make run         # build + launch the .app
make test        # xcodebuild test -scheme Boomer -destination 'platform=macOS'
make lint        # swiftlint + swiftformat --lint
make format      # swiftformat .
make snapshots   # render the pet in each state to /tmp/boomshots (no Screen Recording needed)
```

`make snapshots` runs a DEBUG-only mode (`PetSnapshot`, triggered by the
`BOOMER_SNAPSHOT=<dir>` env var) that uses `ImageRenderer` to write PNGs of the
pet in each state — the way to review art changes when Screen Recording is unavailable.

Run a single test:
```bash
xcodebuild test -scheme Boomer -destination 'platform=macOS' \
  -only-testing:BoomerTests/PetStateMachineTests/celebrateOnDownloadComplete
```

## Architecture

**Logic vs. visuals split:** the Swift `PetStateMachine` owns behavior; **Rive** owns the visual transitions. State changes set Rive state-machine *inputs* — never drive frames manually.

- **`BoomerApp`** — SwiftUI `@main`, an agent app (`LSUIElement`, no Dock icon). The pet has no normal window; `AppDelegate` owns the `PetEngine` and the floating pet window, and `MenuBarExtra` provides controls.
- **`PetWindowController`** — a borderless, transparent, non-activating `NSPanel` hosting `PetView`. Configured `canJoinAllSpaces + fullScreenAuxiliary + stationary` at `.statusBar` level so the pet floats over everything on all Spaces. Mouse interaction is handled by `DraggablePetView` (AppKit, global mouse location) so window drags are smooth and throw velocity can be measured; a click without movement is a "pat".
- **`PetMotion`** (`@Observable`, `@MainActor`) — locomotion/physics: autonomous wandering, gravity, and grab-and-throw. Moves the panel via a `moveHandler` closure and reads `PetEngine.state` (it never owns expression). All coordinates are AppKit screen points (y-up).
- **`PetView` / `PetHead` / `PetStyle`** — the pet's body, hand-drawn anime-style from SwiftUI shapes (dog = Boomer, golden puppy; cat = Buttons, white with amber eyes). `PetView` owns the `BodyPose` system (sitting/standing/walking/running/curled/dangling) and per-pose composition; `PetHead` owns the face (big layered eyes, `FaceParams`); `PetStyle` owns palettes + shapes. Animated by `TimelineView`, modulated by `PetEngine.state` (expression) + `PetMotion` (pose/facing/gait). This is the renderer seam: swap for a Rive-backed view later without touching engine/motion. **Review art changes via `make snapshots`** — never guess at geometry blind.
- **`PetEngine`** (`@Observable`, `@MainActor`) — the brain. Holds `Needs`/`Mood` (hunger/happiness/energy with a 30s decay loop), runs `PetStateMachine`, and drains the `EventBus`. Expressive states (`eating`/`playing`/`celebrating`) are transient and auto-return to `.idle`.
- **`EventBus`** (`AsyncStream<PetEvent>`) — monitors publish, the engine consumes. `MonitorCoordinator` (started once the pet is on screen) owns monitor lifecycles:
  - `FolderMonitor` (GCD file-system source + snapshot diff, state confined to its queue) powers `DownloadMonitor` (`~/Downloads`; pure `DownloadDiff` logic knows browser temp extensions) and `AppInstallMonitor` (`/Applications`, new `.app` bundles). The engine rate-limits celebrations (3s) so an unzip spraying files doesn't cause a minute-long party.
  - `TypingMonitor` — `NSEvent` global keyDown monitor counting **activity only**; the handler never inspects the event. **Never log, store, or transmit keystrokes.** Gated on Input Monitoring and retried until granted (grant may need an app relaunch to take effect).
  - `IdleMonitor` — polls `CGEventSource.secondsSinceLastEventType` (no permission needed); ~4 min idle → sleep, returning activity → wake.
  - Coding-agent celebrations arrive as `boomer://event/agent-done` deep links (Claude Code **Stop hook** bridge, see `scripts/claude-code-stop-hook.sh` and README). The engine celebrates via the bus, and `PetWindowController.celebrateAtFrontmostTerminal()` uses `TerminalLocator` (AX focused-window *geometry only*, known terminal bundle IDs incl. iTerm/Warp/VS Code/Cursor) + `PetMotion.visit` (temporary elevated-floor override) to land the pet on the terminal's top edge, perch ~9s, then glide home. There is no FocusMonitor — the frontmost app is queried on demand.
- **Onboarding** — first-run window (`OnboardingWindowController` + `OnboardingView`): welcome → dog/cat choice with live `PetPreview` cards → naming. Completion flows through `PetStore.completeOnboarding` + `PetEngine.adopt`; if dismissed early, the menu offers "Finish setting up…" (re-opened via the `.boomerShowOnboarding` notification).
- **Multi-pet unlock:** feeds/plays/pats accrue `carePoints` on the engine; at `PetEngine.unlockThreshold` the other species unlocks (with a celebration) and the menu's adopt row becomes "Switch to …".
- **Features:** `Note`/`Reminder` SwiftData models behind `PersistenceService`, shown in `BoardView` (menu → "Notes & Reminders…", standard system controls so it adapts to dark mode). `ReminderScheduler` wraps `UNUserNotificationCenter`; the AppDelegate is the notification delegate, so foreground deliveries also go through the pet (`engine.deliverReminder` → speech bubble + celebration) and mark the record delivered. `FocusTimer` is the Pomodoro companion: pet naps during the session, celebrates the break (plus a notification).
- **AI (`Features/AI/`):** `AIService` wraps Foundation Models — always gate on `SystemLanguageModel.default.availability` (`AIService.state`) and degrade gracefully. One `LanguageModelSession` per species with in-character instructions (`AIService.personality`); streaming via `streamResponse` (`partial.content` is cumulative); context-overflow resets the session but keeps visible history. `ScheduleReminderTool` (`@Generable` args) lets the model create real reminders — `Tool.call` returns a `String` (there is no `ToolOutput` type in the GM SDK). Pet shows `.thinking` (sitting + typing-indicator dots) while generating; replies ≤140 chars also go to the speech bubble. Chat UI in `ChatView`/`ChatWindowController`; clipboard summarize via menu.
- **Speech bubble:** `engine.announce(_:for:)` → `SpeechBubble` inside `PetWindowRoot`. The panel is 220×300 — pet art (200×220) sits at the bottom, the headroom hosts the bubble, and only the pet's body region is clickable (`DraggablePetView.petHitRegion`); everything else clicks through.
- **Platform:** `PermissionsManager` (`@Observable`: Accessibility, Input Monitoring, Notifications), `PetStore` (Codable app-state in `UserDefaults` with a migration-safe decoder — never add a field without a `decodeIfPresent` default), `PersistenceService` (SwiftData container for record data), `PetSpecies` (dog/cat).

## Conventions & gotchas

- **Always build (and run the tests) after a change before claiming it works.** A SwiftUI signature mismatch fails the whole module, so a single missed call site breaks the build.
- **Accessibility:** the pet exposes itself to VoiceOver as one element describing name/species/current state, with bubble announcements appended (`PetWindowRoot.accessibilityDescription`) — keep that in sync when adding states. Don't rely on color alone for meaning.

- **Swift 6 strict concurrency** is on (`complete`). UI and `PetEngine` are `@MainActor`; monitors are `actor`s or run off-main and hand events to the bus. Don't cross isolation without `await`.
- **Rive integration:** add a behavior by exposing an input in the `.riv` state machine, then map `PetState` → that input in one place (`PetEngine.request` / `PetStateMachine`). Keep the Swift enum and the Rive inputs in sync.
- **AI is optional at runtime:** always gate on `SystemLanguageModel.availability` and degrade gracefully when Apple Intelligence is off or still downloading.
- **Permissions are runtime-gated:** features needing Accessibility/Input Monitoring must check `PermissionsManager` (e.g. `AXIsProcessTrusted()`) and route the user to onboarding/Settings instead of failing silently.
- **Entitlements:** the app is intentionally **not** sandboxed (`Config/Boomer.entitlements`). Keep it that way; document any new entitlement in `project.yml`/the entitlements file.
- **Privacy invariant:** typing/window monitors observe *activity and geometry*, never content. Preserve this.
- **Config lives in `Config/`** (`Info.plist`, `Boomer.entitlements`) — outside the `Sources/` tree so XcodeGen doesn't copy them as bundle resources.

## Build status

- **Phase 0 (scaffold):** menu-bar agent, transparent floating panel, `PetEngine`/`PetStateMachine`/`Needs`, `EventBus`, `boomer://` deep link.
- **Phase 1 (live pet):** anime-style hand-drawn SwiftUI dog/cat art (chibi proportions, big layered eyes, collars — gold tag for Boomer, button charm for Buttons) with body poses (sit/walk/run/curl/dangle) and per-state expressions; autonomous wandering + sitting + zoomies + gravity + grab-and-throw physics (`PetMotion`); click-to-pat; menu controls (feed/play/nap/switch species). Real Rive `.riv` art can replace the view layer later.

- **Phase 2 (onboarding + multi-pet):** first-run onboarding (species choice with live previews, naming), `PetStore` persistence with away-time needs decay, care-points unlock of the second pet, gated species switching in the menu.
- **Phase 3 (smart reactions):** download/install celebrations, typing companion (sits + watches your keyboard), idle sleep/wake, sit-on-Terminal coding-agent celebration via the Stop-hook deep link + AX positioning (also an opencode plugin), "Superpowers" permissions submenu, calm mode + temporary hide.
- **Phase 4 (productivity):** notes & reminders board (SwiftData), pet-delivered reminders (speech bubble + notification), focus/Pomodoro companion.
- **Phase 5 (local AI):** in-character chat with streaming, model-driven reminder scheduling via tool calling, clipboard summarize, thinking animation. All on-device; availability-gated.
- **Phase 6 (polish):** generated app icon (`make icon` → `scripts/make-boomer-icon.swift`), sound effects (system sounds, persisted toggle, `engine.soundHandler` keeps the engine AppKit-free), launch at login (`SMAppService`), `DS` tokens (window sizes shared between views and their window controllers), clone-and-build README. Distribution is deliberately source-only (no signing/notarization/updater).

The roadmap is complete; future work is feature ideas (accessories, hotkeys, "watch with me", stats), not phases.
