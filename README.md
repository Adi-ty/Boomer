# Boomer 🐾

A virtual desktop pet for macOS. Boomer lives on your desktop, reacts to what's
happening on your Mac, and keeps you company while you work.

Named after a friend's real pets — **Boomer** the dog and **Buttons** the cat.
Onboarding lets you pick your companion; the other can be unlocked later.

## What it does

- **Lives on the desktop** — a Rive-animated pet floating over all Spaces, draggable, with simple physics.
- **Reacts to your Mac** — jumps when a download or install finishes; hops onto your Terminal and celebrates when a coding agent (e.g. Claude Code) completes; animates while you type.
- **Helps out** — quick notes, reminders/timers, and a focus/Pomodoro companion.
- **On-device AI** — summarize selected text, chat, and small tasks via Apple Intelligence (Foundation Models). Fully local; degrades gracefully when unavailable.

## Requirements

- macOS 26+ (Tahoe), Apple Silicon
- Xcode 26 / Swift 6.3+
- Distributed direct + notarized (intentionally **not** sandboxed)

## Getting started

```bash
make bootstrap   # installs xcodegen/swiftlint/swiftformat (if missing) and generates the project
make run         # build and launch
make test        # run the tests
```

`make` targets are documented via `make help`. The Xcode project is generated
from `project.yml` — don't commit or hand-edit `Boomer.xcodeproj`.

## Claude Code integration

Boomer can celebrate when a Claude Code session finishes. Register the Stop hook
in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "open 'boomer://event/agent-done?agent=claude-code'" }] }
    ]
  }
}
```

Or test it manually:

```bash
open "boomer://event/agent-done?agent=claude-code"
```

## Project layout

```
Config/            Info.plist, entitlements (outside Sources so they aren't copied as resources)
Sources/Boomer/
  App/             @main app, AppDelegate, menu bar
  Window/          floating pet panel + pet view
  Engine/          PetEngine (brain), state machine, needs/mood
  Events/          EventBus + event types (monitors land in Phase 3)
  Pets/            PetSpecies (dog/cat), Pet model
  Platform/        permissions (+ persistence, AI in later phases)
  Features/        Notes / Reminders / AI (later phases)
  Onboarding/      first-run flow (later phase)
Tests/BoomerTests/ unit tests for pure logic
scripts/           Claude Code Stop-hook example
```

See `CLAUDE.md` for architecture details and the phased roadmap in `.claude/plans/`.

## Status

Phase 0 (scaffold) complete: menu-bar agent + transparent pet panel with
placeholder art, the behavior engine, the event bus, and the `boomer://` bridge.
Rive art, system monitors, onboarding, productivity, and AI follow in later phases.
