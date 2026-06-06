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
- Full Xcode 26 / Swift 6.3+ (the Command Line Tools alone can't build a `.app`).
  The `Makefile` auto-points at `/Applications/Xcode.app` if your active toolchain
  is the CLT; the permanent fix is `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Distributed direct + notarized (intentionally **not** sandboxed)

## Install (build from source)

Boomer is distributed as source — clone and build, no signing required:

```bash
git clone https://github.com/Adi-ty/Boomer.git && cd Boomer
make bootstrap   # installs xcodegen/swiftlint/swiftformat (if missing) and generates the project
make run         # build and launch
```

Look for the 🐾 in your menu bar; onboarding opens on first launch.
To update later: `git pull && make run`. Other targets: `make help`
(`test`, `lint`, `snapshots`, `icon`). The Xcode project is generated from
`project.yml` — don't commit or hand-edit `Boomer.xcodeproj`.

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

## opencode integration

Boomer can also celebrate when an [opencode](https://opencode.ai) session finishes.
Install the plugin (fires on the `session.idle` event):

```bash
mkdir -p ~/.config/opencode/plugins
cp scripts/opencode-boomer-plugin.js ~/.config/opencode/plugins/boomer.js
```

Per-project installs work too: `.opencode/plugins/boomer.js`. Any agent can use
the same bridge — just open `boomer://event/agent-done?agent=<name>` when done.

## Project layout

```
Config/            Info.plist, entitlements (outside Sources so they aren't copied as resources)
Sources/Boomer/
  App/             @main app, AppDelegate, menu bar, design tokens
  Window/          floating pet panel, hand-drawn pet art, physics, speech bubble
  Engine/          PetEngine (brain), state machine, needs/mood
  Events/          EventBus + system monitors (downloads/installs/typing/idle)
  Pets/            PetSpecies (dog/cat), Pet model
  Platform/        persistence, permissions, sounds, login item, snapshots
  Features/        notes & reminders board, focus timer, on-device AI chat
  Onboarding/      first-run flow
Tests/BoomerTests/ unit tests for pure logic
scripts/           Claude Code hook, opencode plugin, icon generator
```

See `CLAUDE.md` for architecture details.

## Status

Feature-complete: living hand-drawn pet, onboarding + second-pet adoption,
smart reactions (downloads, installs, typing, idle, coding agents), notes and
pet-delivered reminders, focus sessions, on-device AI chat, sound effects,
launch at login. Distributed as source — clone and build.
