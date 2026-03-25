import Foundation

class AudioPlayer {
    private var process: Process?

    func play(audioPath: String, volume: Double, maxDuration: TimeInterval? = nil) {
        let expandedPath = (audioPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            log("Audio file not found: \(expandedPath)")
            print("Error: Audio file not found at \(expandedPath)")
            print("Place an audio file there or update audio_path in config.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")

        var args = [expandedPath, "-v", String(format: "%.2f", volume)]
        if let duration = maxDuration {
            args += ["-t", String(format: "%.0f", duration)]
        }
        process.arguments = args

        // Suppress afplay output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
            log("Playing audio: \(expandedPath) (volume: \(volume))")
        } catch {
            log("Error playing audio: \(error.localizedDescription)")
            print("Error: Could not play audio — \(error.localizedDescription)")
        }
    }

    func playAndWait(audioPath: String, volume: Double, maxDuration: TimeInterval? = nil) {
        play(audioPath: audioPath, volume: volume, maxDuration: maxDuration)
        process?.waitUntilExit()
    }

    func stop() {
        if let process = process, process.isRunning {
            process.terminate()
            log("Audio stopped")
        }
    }
}
