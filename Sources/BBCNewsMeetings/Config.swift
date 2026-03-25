import Foundation

struct Config: Codable {
    var leadTimeSeconds: Int
    var audioPath: String
    var volume: Double
    var calendars: [String]
    var skipAllDay: Bool
    var skipDeclined: Bool
    var gracePeriodSeconds: Int

    static let defaultConfigDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/bbc-news-meetings")

    static let defaultConfigPath = defaultConfigDir.appendingPathComponent("config.json")
    static let defaultAudioPath = defaultConfigDir.appendingPathComponent("theme.mp3")
    static let defaultStatePath = defaultConfigDir.appendingPathComponent("state.json")
    static let defaultLogPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/bbc-news-meetings.log")

    static let launchAgentLabel = "com.bbc-news-meetings"
    static let launchAgentPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")

    static let `default` = Config(
        leadTimeSeconds: 60,
        audioPath: defaultAudioPath.path,
        volume: 0.7,
        calendars: [],
        skipAllDay: true,
        skipDeclined: true,
        gracePeriodSeconds: 180
    )

    static func load() -> Config {
        guard FileManager.default.fileExists(atPath: defaultConfigPath.path) else {
            return .default
        }
        do {
            let data = try Data(contentsOf: defaultConfigPath)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Config.self, from: data)
        } catch {
            log("Warning: Could not read config, using defaults: \(error.localizedDescription)")
            return .default
        }
    }

    func save() throws {
        let dir = Config.defaultConfigDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Config.defaultConfigPath, options: .atomic)
    }

    var resolvedAudioPath: String {
        (audioPath as NSString).expandingTildeInPath
    }
}

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: Config.defaultLogPath.path) {
            if let handle = try? FileHandle(forWritingTo: Config.defaultLogPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: Config.defaultLogPath)
        }
    }
}
