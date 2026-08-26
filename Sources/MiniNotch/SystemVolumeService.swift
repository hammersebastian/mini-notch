import Foundation

final class SystemVolumeService {
    func readVolume(completion: @escaping (Double?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = self.runAppleScript("output volume of (get volume settings)")
            let value = result.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            DispatchQueue.main.async {
                completion(value.map { min(max($0 / 100.0, 0), 1) })
            }
        }
    }

    func setVolume(_ normalizedValue: Double) {
        let percent = Int((min(max(normalizedValue, 0), 1) * 100).rounded())
        DispatchQueue.global(qos: .utility).async {
            _ = self.runAppleScript("set volume output volume \(percent)")
        }
    }

    private func runAppleScript(_ script: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
