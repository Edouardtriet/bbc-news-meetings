# BBC News Meetings

Play dramatic music before every meeting. Inspired by [@rtwlz](https://x.com/rtwlz/status/2036082537949434164).

A lightweight macOS CLI tool that watches your calendar and plays a fanfare before each meeting starts. Works with any calendar synced to macOS Calendar (Google, iCloud, Exchange, etc.).

## Install

```sh
git clone https://github.com/Edouardtriet/bbc-news-meetings.git
cd bbc-news-meetings
swift build -c release
cp .build/release/bbc-news-meetings /usr/local/bin/
bbc-news-meetings setup
```

## How it works

1. A **LaunchAgent** runs `bbc-news-meetings check` every 30 seconds
2. It queries **EventKit** (macOS Calendar) for events starting within the next 60 seconds
3. When a meeting is found, it plays your audio file using `afplay`
4. A state file prevents the same meeting from triggering twice

That's it. No background daemon, no Electron app, no network requests. Just a single compiled binary.

It works with **every calendar on your Mac** — Google, iCloud, Outlook, Notion, or any account added in System Settings > Internet Accounts. No configuration needed.

## Commands

```
bbc-news-meetings setup      # First-time setup (permissions + config + LaunchAgent)
bbc-news-meetings test       # Play the music now (verify it works)
bbc-news-meetings next       # Show the next meeting and when music would play
bbc-news-meetings status     # Show configuration and LaunchAgent status
bbc-news-meetings start      # Start the LaunchAgent
bbc-news-meetings stop       # Stop the LaunchAgent
bbc-news-meetings uninstall  # Remove everything (config, state, LaunchAgent)
```

## Add the BBC News theme

We'd love to bundle the actual BBC News theme, but David Lowe's lawyers would probably not find that as funny as we do. So you'll need to bring your own dramatic entrance music:

1. Download your audio file (MP3, AAC, M4A, WAV, or AIFF)
2. Open the config folder — run this in your terminal:
   ```sh
   open ~/.config/bbc-news-meetings
   ```
3. Drag your audio file into the folder
4. Rename it to `theme.mp3` (replace the existing one)
5. Run `bbc-news-meetings test` to verify it sounds right

Recommended duration: 30–60 seconds. Audio automatically stops when the meeting starts so it doesn't play over your "hello everyone."

## Configuration

Edit `~/.config/bbc-news-meetings/config.json`:

```json
{
  "lead_time_seconds": 60,
  "audio_path": "~/.config/bbc-news-meetings/theme.mp3",
  "volume": 0.7,
  "calendars": [],
  "skip_all_day": true,
  "skip_declined": true,
  "grace_period_seconds": 180
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `lead_time_seconds` | `60` | Seconds before meeting to start music |
| `audio_path` | `~/.config/bbc-news-meetings/theme.mp3` | Path to audio file |
| `volume` | `0.7` | Volume (0.0 to 1.0) |
| `calendars` | `[]` | Calendar names to watch (empty = all) |
| `skip_all_day` | `true` | Ignore all-day events |
| `skip_declined` | `true` | Ignore declined meetings |
| `grace_period_seconds` | `180` | Still play if meeting started within this window (useful after waking from sleep) |

## Event filtering

| Event type | Plays music? |
|------------|-------------|
| Normal meeting | Yes |
| All-day event | No |
| Declined event | No |
| Tentative event | Yes |
| Cancelled event | No |
| Recurring meeting | Yes (each occurrence) |

## Files

| What | Where |
|------|-------|
| Config | `~/.config/bbc-news-meetings/config.json` |
| Audio | `~/.config/bbc-news-meetings/theme.mp3` |
| State | `~/.config/bbc-news-meetings/state.json` |
| LaunchAgent | `~/Library/LaunchAgents/com.bbc-news-meetings.plist` |
| Logs | `~/Library/Logs/bbc-news-meetings.log` |

## Requirements

- macOS 14 (Sonoma) or later
- Calendar access permission (granted during setup)

## Troubleshooting

**Music doesn't play:**
1. Run `bbc-news-meetings status` to check configuration
2. Run `bbc-news-meetings test` to verify audio works
3. Check `~/Library/Logs/bbc-news-meetings.log` for errors
4. Verify Calendar access in System Settings > Privacy & Security > Calendars

**Permission denied after clicking "Don't Allow":**
Go to System Settings > Privacy & Security > Calendars and toggle access for `bbc-news-meetings`.

**After reboot:**
The LaunchAgent loads automatically on login. No action needed.

## License

MIT
