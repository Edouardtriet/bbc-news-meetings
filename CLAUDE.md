# CLAUDE.md

## What is this?

A macOS CLI tool that plays dramatic music (like the BBC News theme) before every calendar meeting. Built with Swift, EventKit, and a LaunchAgent.

## Build & Run

```sh
swift build                                    # Debug build
swift build -c release                         # Release build
.build/debug/bbc-news-meetings --help          # Show all commands
.build/debug/bbc-news-meetings setup           # First-time setup
.build/debug/bbc-news-meetings test            # Test audio playback
.build/debug/bbc-news-meetings next            # Show next meeting
.build/debug/bbc-news-meetings status          # Show config and status
```

## Install from source

```sh
swift build -c release
cp .build/release/bbc-news-meetings /usr/local/bin/
bbc-news-meetings setup
```

## Architecture

- **Single Swift CLI binary** using ArgumentParser for subcommands
- **EventKit** reads all calendars synced to macOS Calendar (Google, iCloud, Exchange, etc.)
- **LaunchAgent** (`~/Library/LaunchAgents/com.bbc-news-meetings.plist`) runs `check` every 30 seconds
- **afplay** (built-in macOS) plays audio — no dependencies needed
- **State file** (`~/.config/bbc-news-meetings/state.json`) prevents duplicate announcements

## Key files

- `Sources/BBCNewsMeetings/CLI.swift` — All CLI commands (check, test, next, setup, start, stop, status, uninstall)
- `Sources/BBCNewsMeetings/CalendarService.swift` — EventKit queries and event filtering
- `Sources/BBCNewsMeetings/AudioPlayer.swift` — afplay wrapper
- `Sources/BBCNewsMeetings/StateManager.swift` — Announced event tracking
- `Sources/BBCNewsMeetings/Config.swift` — JSON config with defaults

## Custom audio

Replace `~/.config/bbc-news-meetings/theme.mp3` with any MP3/AAC/M4A/WAV/AIFF file. Easiest way: `open ~/.config/bbc-news-meetings` then drag your file in and rename to `theme.mp3`.

## Permissions

The binary needs **Full Calendar Access** (macOS TCC). The `setup` command handles this. If running via LaunchAgent, the binary itself needs the permission (separate from the terminal app).
