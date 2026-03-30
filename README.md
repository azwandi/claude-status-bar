# ClaudeUsageBar

`ClaudeUsageBar` is a native macOS menu bar app that reads Claude Code usage from the local `claude` CLI and shows it in the menu bar as:

`session - week`

Example:

- `0 - 70`
- `12 - 48`

The first number is current session used percentage.
The second number is current week used percentage.

## Features

- Native SwiftUI macOS menu bar app
- CLI-only integration with Claude Code
- Menu bar title shows `session - week`
- Dropdown shows:
  - current session used and remaining
  - current week used and remaining
  - reset timing for session and week
  - weekly model-specific sections when Claude exposes them
  - account/header line from Claude usage output
- Auto-refresh every 60 seconds
- Automatically targets your latest real Claude workspace when possible instead of a dummy probe folder
- Falls back to a dedicated probe folder when no recent Claude session is available

## Why This Exists

Claude Code already exposes usage in `/usage`, but opening the CLI just to check percentages is annoying. This app keeps that information visible from the macOS menu bar without introducing a separate API integration.

This project intentionally does not use Anthropic OAuth/API calls. It reads the same usage data you see in the CLI.

## How It Works

The app launches `claude /usage --allowed-tools ""` inside a pseudo-terminal, captures the rendered terminal output, and parses the usage sections from that screen.

It uses your latest Claude session working directory from `~/.claude/sessions` when available, because probing a fresh folder can produce misleading session numbers.

Core pieces:

- [ClaudeUsageProvider.swift](/Users/azwandi/Documents/New%20project/Sources/ClaudeUsageBar/ClaudeUsageProvider.swift)
  Reads and parses Claude CLI usage output.
- [InteractiveRunner.swift](/Users/azwandi/Documents/New%20project/Sources/ClaudeUsageBar/InteractiveRunner.swift)
  Runs the CLI in a PTY so terminal UI output can be captured correctly.
- [TerminalRenderer.swift](/Users/azwandi/Documents/New%20project/Sources/ClaudeUsageBar/TerminalRenderer.swift)
  Normalizes ANSI/terminal escape output into readable text.
- [UsageStore.swift](/Users/azwandi/Documents/New%20project/Sources/ClaudeUsageBar/UsageStore.swift)
  Owns refresh state and menu bar display values.
- [MenuContentView.swift](/Users/azwandi/Documents/New%20project/Sources/ClaudeUsageBar/MenuContentView.swift)
  Renders the dropdown UI.

## Requirements

- macOS 13+
- Xcode / Swift toolchain installed
- Claude Code CLI installed and available on `PATH`
- Claude CLI logged in

If needed:

```bash
claude login
```

## Run

```bash
swift run ClaudeUsageBar
```

## Build

```bash
swift build
```

## Build a `.app`

```bash
./scripts/build-app.sh
```

This creates:

`dist/ClaudeUsageBar.app`

## Create a `.dmg`

```bash
VERSION=v0.1.0 ./scripts/create-dmg.sh
```

This creates:

`dist/ClaudeUsageBar-v0.1.0.dmg`

## Test

```bash
swift test
```

## Menu Bar Format

The menu bar text is:

`X - Y`

Where:

- `X` = current session used percentage
- `Y` = current week used percentage

The `%` symbol is intentionally omitted to keep the menu bar compact.

## Dropdown Details

The dropdown shows a summary card plus a breakdown section.

Summary card:

- session used
- weekly used
- session remaining
- session progress bar
- session reset
- week reset

Breakdown section:

- Current session
- Current week (all models)
- Current week (Opus), if present
- Current week (Sonnet), if present

Each breakdown card shows:

- used percentage
- remaining percentage
- reset text when available

## Working Directory Behavior

Claude’s `/usage` output depends on where the CLI is run. If it is run in a fresh standalone folder, session usage can look empty or reset.

To make the app more useful, `ClaudeUsageBar` tries to probe usage from your latest Claude session workspace by reading session metadata from:

`~/.claude/sessions`

If no suitable recent session is found, it falls back to:

`~/Library/Application Support/ClaudeUsageBar/Probe`

You can reveal the currently used directory from the dropdown via `Reveal Probe`.

## Known Limitations

- The app is only as accurate as `claude /usage`.
- If Claude itself reports `0` for the current session, the app will also show `0`.
- Session usage may vary depending on which Claude workspace/session is currently active.
- The CLI UI can change across Claude versions, so parsing may need updates if the `/usage` screen changes significantly.

## Design Choices

- No Anthropic OAuth/API integration
- No browser automation
- No scraping from Claude web pages
- Uses the local Claude CLI as the single source of truth

## Future Improvements

- Launch at login
- App icon polish and signing/notarization
- Optional toggle for `used` vs `remaining`
- Optional menu bar mode presets such as `session only`, `week only`, or `session - week - opus`
- Better active-session selection when multiple Claude workspaces are open

## Release Automation

This repo includes a GitHub Actions workflow at:

`/.github/workflows/release-dmg.yml`

When you push a tag like:

```bash
git tag v0.1.1
git push origin v0.1.1
```

the workflow will:

- build the macOS app bundle
- package it as a `.dmg`
- upload the `.dmg` to the matching GitHub release
