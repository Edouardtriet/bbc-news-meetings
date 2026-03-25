import Foundation

public struct Config: Codable {
    public var leadTimeSeconds: Int
    public var audioPath: String
    public var volume: Double
    public var calendars: [String]
    public var skipAllDay: Bool
    public var skipDeclined: Bool
    public var gracePeriodSeconds: Int

    public static let defaultConfigDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/bbc-news-meetings")

    public static let defaultConfigPath = defaultConfigDir.appendingPathComponent("config.json")
    public static let defaultAudioPath = defaultConfigDir.appendingPathComponent("theme.mp3")
    public static let defaultStatePath = defaultConfigDir.appendingPathComponent("state.json")
    public static let defaultLogPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/bbc-news-meetings.log")

    public static let launchAgentLabel = "com.bbc-news-meetings"
    public static let launchAgentPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")

    public static let `default` = Config(
        leadTimeSeconds: 60,
        audioPath: defaultAudioPath.path,
        volume: 0.7,
        calendars: [],
        skipAllDay: true,
        skipDeclined: true,
        gracePeriodSeconds: 180
    )

    public static func load() -> Config {
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

    public func save() throws {
        let dir = Config.defaultConfigDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Config.defaultConfigPath, options: .atomic)
    }

    public var resolvedAudioPath: String {
        (audioPath as NSString).expandingTildeInPath
    }
}

public func log(_ message: String) {
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
