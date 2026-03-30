# CodexStatusBar

`CodexStatusBar` is a native macOS menu bar app that shows your latest Codex usage directly from local session data.

It reads the most recent usage snapshot written by Codex under `~/.codex/sessions` and renders the current short-window and weekly usage in the menu bar as:

`primary - weekly`

Examples:

- `38 - 12`
- `4 - 1`

The first number is the current primary rate-limit window usage percentage.
The second number is the current secondary or weekly usage percentage when Codex exposes it.

## Features

- Native SwiftUI macOS menu bar app
- Local-only integration with Codex session data in `~/.codex/sessions`
- Compact menu bar title with red, amber, and green usage colors
- Dropdown cards for:
  - the primary rate-limit window
  - the secondary window when present
  - reset timestamps
  - current Codex plan label
- Immediate refresh on launch
- Background polling every 4 minutes for 60 minutes after activation
- Disabled mode that collapses the title to `Codex`
- `Reload`, `Disable`, and `Check for Updates` actions
- GitHub release updater for installed app bundles

## Why This Exists

Codex already records usage snapshots while you work, but checking them manually means digging through JSONL session files. `CodexStatusBar` keeps the latest usage visible in the macOS menu bar without needing browser automation or a separate billing integration.

## How It Works

The app scans:

`~/.codex/sessions`

It opens the most recently updated session files, finds the newest `token_count` event with `rate_limits`, and extracts:

- `rate_limits.primary`
- `rate_limits.secondary`
- `plan_type`

Those values drive both the menu bar title and the dropdown breakdown cards.

## Project Structure

- [CodexUsageProvider.swift](/Users/azwandi/Development/codex-status-bar/Sources/CodexStatusBar/CodexUsageProvider.swift)
  Reads and parses Codex session usage snapshots.
- [UsageStore.swift](/Users/azwandi/Development/codex-status-bar/Sources/CodexStatusBar/UsageStore.swift)
  Manages refresh state, display values, and update checks.
- [MenuContentView.swift](/Users/azwandi/Development/codex-status-bar/Sources/CodexStatusBar/MenuContentView.swift)
  Renders the dropdown UI.
- [AppDelegate.swift](/Users/azwandi/Development/codex-status-bar/Sources/CodexStatusBar/AppDelegate.swift)
  Owns the status item and popover lifecycle.
- [AppUpdater.swift](/Users/azwandi/Development/codex-status-bar/Sources/CodexStatusBar/AppUpdater.swift)
  Checks GitHub releases and installs newer app bundles when possible.

## Requirements

- macOS 13+
- Xcode or the Swift toolchain
- Codex installed locally
- At least one existing Codex session so `~/.codex/sessions` exists

## Running Locally

From the project root:

```bash
swift run CodexStatusBar
```

## Building

Build the executable:

```bash
swift build
```

Run tests:

```bash
swift test
```

Build a macOS app bundle:

```bash
APP_VERSION=0.2.0 ./scripts/build-app.sh
```

This creates:

`dist/CodexStatusBar.app`

Create a DMG:

```bash
VERSION=v0.2.0 ./scripts/create-dmg.sh
```

This creates:

`dist/CodexStatusBar-v0.2.0.dmg`

## Menu Bar Format

The menu bar text is:

`X - Y`

Where:

- `X` = primary window used percentage
- `Y` = secondary or weekly window used percentage

The `%` symbol is omitted to keep the menu bar compact.

## Dropdown Details

The dropdown shows:

- the Codex plan from the latest usage snapshot
- a card for each available usage window
- percent used
- percent remaining
- reset timing when available
- last refresh time
- app version
- update status or parser errors when relevant

Footer actions:

- `Reload` refreshes usage immediately
- `Check for Updates` checks the latest GitHub release
- `Disable` stops background refreshes until the menu is opened again
- `Quit` exits the app

## Known Limitations

- The app is only as accurate as the latest Codex session snapshot on disk.
- If no recent `token_count` event has been written yet, the app cannot show usage.
- If Codex changes its local JSONL schema, the parser may need to be updated.
- The current updater expects GitHub release assets and works best when the app is launched from an installed `.app` bundle.

## Design Choices

- No browser automation
- No scraping from web pages
- No separate OpenAI billing API integration
- Local Codex session data is the source of truth

## Release Process

Build the release artifacts:

```bash
APP_VERSION=0.2.0 ./scripts/build-app.sh
VERSION=v0.2.0 ./scripts/create-dmg.sh
```

Then publish a GitHub release and attach the generated DMG.
