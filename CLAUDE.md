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
- **`PetView`** — the pet's body, hand-drawn from SwiftUI shapes (dog = Boomer, cat = Buttons), animated by `TimelineView` and modulated by `PetEngine.state` (expression) + `PetMotion` (facing/gait). This is the renderer seam: swap it for a Rive-backed view later without touching engine/motion.
- **`PetEngine`** (`@Observable`, `@MainActor`) — the brain. Holds `Needs`/`Mood` (hunger/happiness/energy with a 30s decay loop), runs `PetStateMachine`, and drains the `EventBus`. Expressive states (`eating`/`playing`/`celebrating`) are transient and auto-return to `.idle`.
- **`EventBus`** (`AsyncStream<PetEvent>`) — monitors publish, the engine consumes. Monitors are isolated services/actors (Phase 3):
  - `DownloadMonitor` (FSEvents on `~/Downloads`), `AppInstallMonitor` (`/Applications`), `IdleMonitor` (idle/night → sleep), `FocusMonitor` (`NSWorkspace` frontmost app).
  - `TypingMonitor` — detects typing **activity only** (a boolean rate). **Never log, store, or transmit keystrokes.**
  - `CodingAgentMonitor` — receives `boomer://` URL events (Claude Code **Stop hook** bridge, see `scripts/claude-code-stop-hook.sh`) and uses `AXUIElement` to position the pet over the frontmost Terminal window before celebrating.
- **Features (later phases):** `NotesStore`, reminders/Pomodoro (`UserNotifications`), `AIService` (Foundation Models).
- **Platform:** `PermissionsManager` (Accessibility, Input Monitoring, Notifications, Apple Intelligence), SwiftData persistence, `PetSpecies` (dog/cat) with per-species Rive/sound assets.

## Conventions & gotchas

- **Swift 6 strict concurrency** is on (`complete`). UI and `PetEngine` are `@MainActor`; monitors are `actor`s or run off-main and hand events to the bus. Don't cross isolation without `await`.
- **Rive integration:** add a behavior by exposing an input in the `.riv` state machine, then map `PetState` → that input in one place (`PetEngine.request` / `PetStateMachine`). Keep the Swift enum and the Rive inputs in sync.
- **AI is optional at runtime:** always gate on `SystemLanguageModel.availability` and degrade gracefully when Apple Intelligence is off or still downloading.
- **Permissions are runtime-gated:** features needing Accessibility/Input Monitoring must check `PermissionsManager` (e.g. `AXIsProcessTrusted()`) and route the user to onboarding/Settings instead of failing silently.
- **Entitlements:** the app is intentionally **not** sandboxed (`Config/Boomer.entitlements`). Keep it that way; document any new entitlement in `project.yml`/the entitlements file.
- **Privacy invariant:** typing/window monitors observe *activity and geometry*, never content. Preserve this.
- **Config lives in `Config/`** (`Info.plist`, `Boomer.entitlements`) — outside the `Sources/` tree so XcodeGen doesn't copy them as bundle resources.

## Build status

- **Phase 0 (scaffold):** menu-bar agent, transparent floating panel, `PetEngine`/`PetStateMachine`/`Needs`, `EventBus`, `boomer://` deep link.
- **Phase 1 (live pet):** hand-drawn SwiftUI dog/cat art with per-state expressions, autonomous wandering + gravity + grab-and-throw physics (`PetMotion`), click-to-pat, menu controls (feed/play/nap/switch species). Real Rive `.riv` art can replace `PetView` later.

Next up: Phase 2 (onboarding + multi-pet unlock), Phase 3 (system monitors: downloads/typing/coding-agent), Phase 4 (productivity), Phase 5 (local AI). See the plan in `.claude/plans/`.
