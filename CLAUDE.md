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
```

Run a single test:
```bash
xcodebuild test -scheme Boomer -destination 'platform=macOS' \
  -only-testing:BoomerTests/PetStateMachineTests/celebrateOnDownloadComplete
```

## Architecture

**Logic vs. visuals split:** the Swift `PetStateMachine` owns behavior; **Rive** owns the visual transitions. State changes set Rive state-machine *inputs* — never drive frames manually.

- **`BoomerApp`** — SwiftUI `@main`, an agent app (`LSUIElement`, no Dock icon). The pet has no normal window; `AppDelegate` owns the `PetEngine` and the floating pet window, and `MenuBarExtra` provides controls.
- **`PetWindowController`** — a borderless, transparent, non-activating `NSPanel` hosting `RivePetView`. Configured `canJoinAllSpaces + fullScreenAuxiliary + stationary` at `.statusBar` level so the pet floats over everything on all Spaces. Empty regions are click-through; the pet sprite is interactive (drag + physics arrive in Phase 1).
- **`PetEngine`** (`@Observable`, `@MainActor`) — the brain. Holds `Needs`/`Mood` (hunger/happiness/energy with a 30s decay loop), runs `PetStateMachine`, and drains the `EventBus`.
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

Phase 0 (scaffold) is in place: menu-bar agent, transparent pet panel with placeholder SF Symbol art, `PetEngine`/`PetStateMachine`/`Needs`, `EventBus`, and the `boomer://` deep-link entry point. Rive rendering, monitors, onboarding, productivity, and local AI land in later phases (see the plan in `.claude/plans/`).
