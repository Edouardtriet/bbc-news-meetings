import Foundation

struct AnnouncedEvent: Codable {
    let eventId: String
    let announcedAt: Date
}

struct State: Codable {
    var announcedEvents: [AnnouncedEvent]

    static let empty = State(announcedEvents: [])
}

class StateManager {
    private let path: URL

    init(path: URL = Config.defaultStatePath) {
        self.path = path
    }

    func load() -> State {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(State.self, from: data)
        } catch {
            log("Warning: Could not read state file, starting fresh: \(error.localizedDescription)")
            return .empty
        }
    }

    func save(_ state: State) {
        do {
            let dir = path.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: path, options: .atomic)
        } catch {
            log("Error saving state: \(error.localizedDescription)")
        }
    }

    func hasBeenAnnounced(eventId: String, state: State) -> Bool {
        return state.announcedEvents.contains { $0.eventId == eventId }
    }

    func markAnnounced(eventId: String, state: inout State) {
        state.announcedEvents.append(AnnouncedEvent(eventId: eventId, announcedAt: Date()))
    }

    func pruneOldEntries(state: inout State) {
        let cutoff = Date().addingTimeInterval(-24 * 3600) // 24 hours ago
        state.announcedEvents.removeAll { $0.announcedAt < cutoff }
    }
}
