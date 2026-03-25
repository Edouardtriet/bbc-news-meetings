import Foundation

public class AudioPlayer {
    private var process: Process?

    public init() {}

    public func play(audioPath: String, volume: Double, maxDuration: TimeInterval? = nil) {
        let expandedPath = (audioPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            log("Audio file not found: \(expandedPath)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")

        var args = [expandedPath, "-v", String(format: "%.2f", volume)]
        if let duration = maxDuration {
            args += ["-t", String(format: "%.0f", duration)]
        }
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
            log("Playing audio: \(expandedPath) (volume: \(volume))")
        } catch {
            log("Error playing audio: \(error.localizedDescription)")
        }
    }

    public func playAndWait(audioPath: String, volume: Double, maxDuration: TimeInterval? = nil) {
        play(audioPath: audioPath, volume: volume, maxDuration: maxDuration)
        process?.waitUntilExit()
    }

    public func stop() {
        if let process = process, process.isRunning {
            process.terminate()
            log("Audio stopped")
        }
    }

    public var isPlaying: Bool {
        process?.isRunning ?? false
    }
}
