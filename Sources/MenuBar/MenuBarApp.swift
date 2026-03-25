import BBCNewsMeetingsCore
import SwiftUI

@main
struct BBCNewsMeetingsMenuBar: App {
    @StateObject private var viewModel = MeetingViewModel()

    var body: some Scene {
        MenuBarExtra {
            if let event = viewModel.nextEvent {
                Text(event.title)
                    .font(.headline)
                Text(event.calendarName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
            } else {
                Text("No upcoming meetings")
                    .foregroundStyle(.secondary)
                Divider()
            }

            if viewModel.isPlayingMusic {
                Button("Stop Music") {
                    viewModel.stopMusic()
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Text(viewModel.menuBarTitle)
        }
    }
}

@MainActor
class MeetingViewModel: ObservableObject {
    @Published var nextEvent: UpcomingEvent?
    @Published var isPlayingMusic = false
    @Published var menuBarTitle = "No meetings"

    private let calendar = CalendarService()
    private let config = Config.load()
    private let stateManager = StateManager()
    private let player = AudioPlayer()
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?

    init() {
        // Request access if needed
        if calendar.checkAccess() == .notDetermined {
            _ = calendar.requestAccess()
        }

        // Refresh calendar every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNextEvent() }
        }
        refreshNextEvent()

        // Update countdown every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateCountdown() }
        }
    }

    func refreshNextEvent() {
        guard calendar.checkAccess() == .fullAccess else {
            menuBarTitle = "No calendar access"
            return
        }

        nextEvent = calendar.findNextEvent(config: config)
        updateCountdown()
        checkAndPlayMusic()
    }

    func updateCountdown() {
        guard let event = nextEvent else {
            menuBarTitle = "No meetings"
            return
        }

        let now = Date()
        let seconds = Int(event.startDate.timeIntervalSince(now))

        if seconds <= 0 {
            // Meeting started — refresh to find the next one
            refreshNextEvent()
            return
        }

        let m = seconds / 60
        let s = seconds % 60
        menuBarTitle = "\(event.title) in \(m):\(String(format: "%02d", s))"
    }

    func checkAndPlayMusic() {
        guard let event = nextEvent else { return }

        let secondsUntil = event.startDate.timeIntervalSince(Date())
        guard secondsUntil > 0 && secondsUntil <= Double(config.leadTimeSeconds) else { return }

        var state = stateManager.load()
        guard !stateManager.hasBeenAnnounced(eventId: event.id, state: state) else { return }

        log("Meeting detected: \"\(event.title)\" (\(event.formattedTimeUntil)) — playing music")
        player.play(audioPath: config.resolvedAudioPath, volume: config.volume, maxDuration: secondsUntil)
        isPlayingMusic = true
        stateManager.markAnnounced(eventId: event.id, state: &state)
        stateManager.pruneOldEntries(state: &state)
        stateManager.save(state)

        // Auto-update isPlaying when music finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + secondsUntil + 1) { [weak self] in
            self?.isPlayingMusic = false
        }
    }

    func stopMusic() {
        player.stop()
        isPlayingMusic = false
    }
}
