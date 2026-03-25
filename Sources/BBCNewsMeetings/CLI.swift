import ArgumentParser
import Darwin
import Foundation

func forceUnbufferedOutput() {
    setbuf(stdout, nil)
    setbuf(stderr, nil)
}

@main
struct BBCNewsMeetings: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bbc-news-meetings",
        abstract: "Play dramatic music before every meeting.",
        version: "1.0.0",
        subcommands: [Check.self, Test.self, Next.self, Setup.self, Start.self, Stop.self, Status.self, Uninstall.self]
    )
}

// MARK: - Check (called by LaunchAgent every 30s)

struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check for upcoming meetings and play music if needed (used by LaunchAgent)."
    )

    func run() throws {
        forceUnbufferedOutput()
        let config = Config.load()
        let calendar = CalendarService()
        let stateManager = StateManager()
        var state = stateManager.load()

        // Prune old entries
        stateManager.pruneOldEntries(state: &state)

        var status = calendar.checkAccess()
        if status == .notDetermined {
            let granted = calendar.requestAccess()
            status = granted ? .fullAccess : .denied
        }
        guard status == .fullAccess else {
            log("Calendar access not granted (status: \(status.rawValue)). Run 'bbc-news-meetings setup' first.")
            return
        }

        let events = calendar.findUpcomingEvents(config: config)

        for event in events {
            guard !stateManager.hasBeenAnnounced(eventId: event.id, state: state) else {
                continue
            }

            log("Meeting detected: \"\(event.title)\" (\(event.formattedTimeUntil)) — playing music")

            // Show macOS notification
            showNotification(title: event.title, subtitle: event.formattedTimeUntil, calendarName: event.calendarName)

            // Calculate max duration: stop audio when meeting starts (or now if already started)
            let maxDuration = max(event.secondsUntilStart, 0)
            let player = AudioPlayer()

            if maxDuration > 0 {
                player.play(audioPath: config.resolvedAudioPath, volume: config.volume, maxDuration: maxDuration)
            } else {
                // Meeting already started (grace period) — short burst
                player.play(audioPath: config.resolvedAudioPath, volume: config.volume, maxDuration: 10)
            }

            stateManager.markAnnounced(eventId: event.id, state: &state)
        }

        stateManager.save(state)
    }
}

// MARK: - Test

struct Test: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Play the music right now to verify everything works."
    )

    func run() throws {
        forceUnbufferedOutput()
        let config = Config.load()
        let path = config.resolvedAudioPath

        guard FileManager.default.fileExists(atPath: path) else {
            print("No audio file found at: \(path)")
            print("")
            print("To add music:")
            print("  1. Run: open ~/.config/bbc-news-meetings")
            print("  2. Drag your audio file into the folder")
            print("  3. Rename it to theme.mp3")
            print("")
            print("Supported formats: MP3, AAC, M4A, WAV, AIFF")
            throw ExitCode.failure
        }

        print("Playing: \(path)")
        print("Press Ctrl+C to stop")
        let player = AudioPlayer()
        player.playAndWait(audioPath: path, volume: config.volume)
    }
}

// MARK: - Next

struct Next: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the next upcoming meeting."
    )

    func run() throws {
        forceUnbufferedOutput()
        let config = Config.load()
        let calendar = CalendarService()

        let status = calendar.checkAccess()
        guard status == .fullAccess else {
            print("Calendar access not granted.")
            print("Run: bbc-news-meetings setup")
            throw ExitCode.failure
        }

        guard let event = calendar.findNextEvent(config: config) else {
            print("No upcoming meetings in the next 24 hours.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: event.startDate)

        print("\(event.title)")
        print("  Calendar: \(event.calendarName)")
        print("  Time:     \(timeStr) (\(event.formattedTimeUntil))")

        let musicTime = event.startDate.addingTimeInterval(-TimeInterval(config.leadTimeSeconds))
        if musicTime > Date() {
            let musicFormatter = DateFormatter()
            musicFormatter.dateFormat = "HH:mm:ss"
            print("  Music at: \(musicFormatter.string(from: musicTime))")
        } else if event.secondsUntilStart > 0 {
            print("  Music:    would play NOW")
        } else {
            print("  Music:    already passed")
        }
    }
}

// MARK: - Setup

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "First-time setup: permissions, config, LaunchAgent, and test."
    )

    func run() throws {
        forceUnbufferedOutput()
        print("BBC News Meetings — Setup")
        print("=========================")
        print("")

        // Step 1: Calendar permissions
        print("Step 1/4: Checking calendar access...")
        let calendar = CalendarService()
        let authStatus = calendar.checkAccess()

        switch authStatus {
        case .fullAccess:
            print("  Calendar access already granted.")
        case .notDetermined:
            print("  Requesting calendar access (macOS will prompt you)...")
            let granted = calendar.requestAccess()
            if granted {
                print("  Calendar access granted.")
            } else {
                print("  Calendar access denied.")
                print("")
                print("  Please grant access in:")
                print("  System Settings > Privacy & Security > Calendars")
                print("")
                print("  Then run 'bbc-news-meetings setup' again.")
                throw ExitCode.failure
            }
        case .denied:
            print("  Calendar access was previously denied.")
            print("")
            print("  To fix, open:")
            print("    System Settings > Privacy & Security > Calendars")
            print("  and toggle ON access for Terminal (or bbc-news-meetings).")
            print("")
            print("  Then run 'bbc-news-meetings setup' again.")
            throw ExitCode.failure
        default:
            print("  Calendar access unavailable (status: \(authStatus.rawValue)).")
            throw ExitCode.failure
        }

        // Step 2: Config
        print("")
        print("Step 2/4: Creating config...")
        let config = Config.default
        do {
            try config.save()
            print("  Config saved to: \(Config.defaultConfigPath.path)")
        } catch {
            print("  Error creating config: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Step 3: Audio file
        print("")
        print("Step 3/4: Checking audio file...")
        let audioPath = config.resolvedAudioPath
        if FileManager.default.fileExists(atPath: audioPath) {
            print("  Audio file found: \(audioPath)")
        } else {
            // Copy bundled default or create placeholder
            let configDir = Config.defaultConfigDir
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

            if let bundledURL = Bundle.module.url(forResource: "default-fanfare", withExtension: "mp3", subdirectory: "Resources") {
                try FileManager.default.copyItem(at: bundledURL, to: Config.defaultAudioPath)
                print("  Default fanfare copied to: \(audioPath)")
            } else {
                // Use a system sound as fallback
                let systemSound = "/System/Library/Sounds/Hero.aiff"
                if FileManager.default.fileExists(atPath: systemSound) {
                    try FileManager.default.copyItem(
                        atPath: systemSound,
                        toPath: audioPath
                    )
                    print("  Using system sound (Hero) as placeholder.")
                    print("")
                    print("  To add your own music:")
                    print("    1. Run: open \(configDir.path)")
                    print("    2. Drag your audio file into the folder")
                    print("    3. Rename it to theme.mp3")
                } else {
                    print("  No audio file found. To add music:")
                    print("    1. Run: open \(configDir.path)")
                    print("    2. Drag your audio file into the folder")
                    print("    3. Rename it to theme.mp3")
                }
            }
        }

        // Step 4: LaunchAgent
        print("")
        print("Step 4/4: Installing LaunchAgent...")
        try installLaunchAgent()
        print("  LaunchAgent installed and loaded.")

        // Done
        print("")
        print("Setup complete!")
        print("")

        // Show next meeting
        if let event = calendar.findNextEvent(config: config) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            print("Next meeting: \(event.title) at \(formatter.string(from: event.startDate)) (\(event.formattedTimeUntil))")
        } else {
            print("No upcoming meetings. Run 'bbc-news-meetings test' to hear the music.")
        }
    }
}

// MARK: - Start / Stop

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start the LaunchAgent (load it)."
    )

    func run() throws {
        forceUnbufferedOutput()
        let plistPath = Config.launchAgentPath.path
        guard FileManager.default.fileExists(atPath: plistPath) else {
            print("LaunchAgent not installed. Run 'bbc-news-meetings setup' first.")
            throw ExitCode.failure
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("Started. Music will play before your meetings.")
        } else {
            print("Could not load LaunchAgent. It may already be running.")
        }
    }
}

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop the LaunchAgent (unload it)."
    )

    func run() throws {
        forceUnbufferedOutput()
        let plistPath = Config.launchAgentPath.path
        guard FileManager.default.fileExists(atPath: plistPath) else {
            print("LaunchAgent not installed.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("Stopped. No more music before meetings.")
        } else {
            print("Could not unload LaunchAgent. It may not be running.")
        }
    }
}

// MARK: - Status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current status and configuration."
    )

    func run() throws {
        forceUnbufferedOutput()
        let config = Config.load()
        let calendar = CalendarService()
        let access = calendar.checkAccess()

        print("BBC News Meetings — Status")
        print("==========================")
        print("")

        // Calendar access
        let accessStr: String
        switch access {
        case .fullAccess: accessStr = "granted"
        case .notDetermined: accessStr = "not requested (run setup)"
        case .denied: accessStr = "denied (grant in System Settings)"
        case .restricted: accessStr = "restricted"
        case .writeOnly: accessStr = "write-only (need full access)"
        @unknown default: accessStr = "unknown"
        }
        print("Calendar access: \(accessStr)")

        // LaunchAgent
        let agentInstalled = FileManager.default.fileExists(atPath: Config.launchAgentPath.path)
        print("LaunchAgent:     \(agentInstalled ? "installed" : "not installed")")

        if agentInstalled {
            // Check if loaded
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["list", Config.launchAgentLabel]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            let running = process.terminationStatus == 0
            print("Running:         \(running ? "yes" : "no")")
        }

        // Audio
        let audioExists = FileManager.default.fileExists(atPath: config.resolvedAudioPath)
        print("Audio file:      \(audioExists ? config.resolvedAudioPath : "missing (\(config.resolvedAudioPath))")")

        // Config
        print("")
        print("Configuration:")
        print("  Lead time:     \(config.leadTimeSeconds)s before meeting")
        print("  Volume:        \(String(format: "%.0f%%", config.volume * 100))")
        print("  Calendars:     \(config.calendars.isEmpty ? "all" : config.calendars.joined(separator: ", "))")
        print("  Skip all-day:  \(config.skipAllDay)")
        print("  Skip declined: \(config.skipDeclined)")
        print("  Grace period:  \(config.gracePeriodSeconds)s")
    }
}

// MARK: - Uninstall

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove LaunchAgent, config, state, and logs."
    )

    func run() throws {
        forceUnbufferedOutput()
        print("Uninstalling BBC News Meetings...")
        print("")

        // Stop LaunchAgent
        let plistPath = Config.launchAgentPath.path
        if FileManager.default.fileExists(atPath: plistPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", plistPath]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            try? FileManager.default.removeItem(atPath: plistPath)
            print("  Removed LaunchAgent")
        }

        // Remove config directory
        let configDir = Config.defaultConfigDir
        if FileManager.default.fileExists(atPath: configDir.path) {
            try FileManager.default.removeItem(at: configDir)
            print("  Removed config directory: \(configDir.path)")
        }

        // Remove log file
        if FileManager.default.fileExists(atPath: Config.defaultLogPath.path) {
            try FileManager.default.removeItem(at: Config.defaultLogPath)
            print("  Removed log file")
        }

        print("")
        print("Done. The binary is still installed — remove it with:")
        print("  brew uninstall bbc-news-meetings")
        print("  # or: rm $(which bbc-news-meetings)")
    }
}

// MARK: - Helpers

func installLaunchAgent() throws {
    // Find the binary path
    let binaryPath = ProcessInfo.processInfo.arguments[0]
    let resolvedBinary: String
    if binaryPath.hasPrefix("/") {
        resolvedBinary = binaryPath
    } else {
        // Resolve relative path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["bbc-news-meetings"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedBinary = output ?? binaryPath
    }

    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>\(Config.launchAgentLabel)</string>
        <key>ProgramArguments</key>
        <array>
            <string>\(resolvedBinary)</string>
            <string>check</string>
        </array>
        <key>StartInterval</key>
        <integer>30</integer>
        <key>StandardOutPath</key>
        <string>\(Config.defaultLogPath.path)</string>
        <key>StandardErrorPath</key>
        <string>\(Config.defaultLogPath.path)</string>
        <key>RunAtLoad</key>
        <true/>
    </dict>
    </plist>
    """

    let agentDir = Config.launchAgentPath.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)
    try plist.write(to: Config.launchAgentPath, atomically: true, encoding: .utf8)

    // Load the agent
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = ["load", Config.launchAgentPath.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
}

func showNotification(title: String, subtitle: String, calendarName: String) {
    let script = """
    display notification "\(calendarName)" with title "🔴 \(title)" subtitle "\(subtitle)"
    """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
}
