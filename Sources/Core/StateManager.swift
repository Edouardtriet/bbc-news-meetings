import Foundation

public struct AnnouncedEvent: Codable {
    public let eventId: String
    public let announcedAt: Date
}

public struct State: Codable {
    public var announcedEvents: [AnnouncedEvent]

    public static let empty = State(announcedEvents: [])
}

public class StateManager {
    private let path: URL

    public init(path: URL = Config.defaultStatePath) {
        self.path = path
    }

    public func load() -> State {
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

    public func save(_ state: State) {
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

    public func hasBeenAnnounced(eventId: String, state: State) -> Bool {
        return state.announcedEvents.contains { $0.eventId == eventId }
    }

    public func markAnnounced(eventId: String, state: inout State) {
        state.announcedEvents.append(AnnouncedEvent(eventId: eventId, announcedAt: Date()))
    }

    public func pruneOldEntries(state: inout State) {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        state.announcedEvents.removeAll { $0.announcedAt < cutoff }
    }
}
