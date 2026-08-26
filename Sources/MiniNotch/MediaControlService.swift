import AppKit
import Foundation

final class MediaControlService {
    var onStateUpdate: ((MediaState) -> Void)?
    var onError: ((String) -> Void)?

    private var streamProcess: Process?
    private var streamPipe: Pipe?
    private var errorPipe: Pipe?
    private var buffer = Data()

    private let processingQueue = DispatchQueue(label: "de.mininotch.media-control")

    private lazy var executablePath: String? = locateMediaControl()

    deinit {
        stop()
    }

    func start() {
        guard let executablePath else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("media-control wurde nicht gefunden. Führe im Projekt ./scripts/setup.sh aus.")
            }
            return
        }

        stop()

        let process = Process()
        let stdout = Pipe()
        let errorOutput = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["stream", "--no-diff"]
        process.standardOutput = stdout
        process.standardError = errorOutput

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.processingQueue.async {
                self?.consume(data)
            }
        }

        errorOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            FileHandle.standardError.write(Data("media-control: \(text)".utf8))
        }

        process.terminationHandler = { [weak self] process in
            self?.streamPipe?.fileHandleForReading.readabilityHandler = nil
            self?.errorPipe?.fileHandleForReading.readabilityHandler = nil

            guard process.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                self?.onError?("media-control wurde unerwartet beendet (Code \(process.terminationStatus)).")
            }
        }

        do {
            try process.run()
            streamProcess = process
            streamPipe = stdout
            errorPipe = errorOutput
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("media-control konnte nicht gestartet werden: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        streamPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        if streamProcess?.isRunning == true {
            streamProcess?.terminate()
        }

        streamProcess = nil
        streamPipe = nil
        errorPipe = nil
        buffer.removeAll(keepingCapacity: false)
    }

    func togglePlayPause() {
        runCommand(["toggle-play-pause"])
    }

    func next() {
        runCommand(["next-track"])
    }

    func previous() {
        runCommand(["previous-track"])
    }

    func seek(to seconds: Double) {
        let micros = max(0, Int64(seconds * 1_000_000))
        runCommand(["seek", String(micros)])
    }

    private func runCommand(_ arguments: [String]) {
        guard let executablePath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Medienbefehl fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            guard !line.isEmpty else { continue }
            decode(line)
        }
    }

    private func decode(_ data: Data) {
        do {
            let event = try JSONDecoder().decode(StreamEvent.self, from: data)
            let payload = event.payload

            let artwork: NSImage?
            if let artworkString = payload.artworkData,
               let artworkData = Data(base64Encoded: artworkString) {
                artwork = NSImage(data: artworkData)
            } else {
                artwork = nil
            }

            let state = MediaState(
                bundleIdentifier: payload.bundleIdentifier ?? "",
                title: payload.title ?? "",
                artist: payload.artist ?? "",
                album: payload.album ?? "",
                isPlaying: payload.playing ?? false,
                duration: payload.duration ?? 0,
                elapsedTime: payload.elapsedTime ?? 0,
                artwork: artwork,
                receivedAt: Date()
            )

            DispatchQueue.main.async { [weak self] in
                self?.onStateUpdate?(state)
            }
        } catch {
            // Einzelne unvollständige oder zukünftige Payloads sollen die App nicht stoppen.
            print("MiniNotch: media-control JSON konnte nicht gelesen werden: \(error)")
        }
    }

    private func locateMediaControl() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/media-control",
            "/usr/local/bin/media-control"
        ]

        if let known = knownPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return known
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for folder in path.split(separator: ":") {
            let candidate = String(folder) + "/media-control"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}

private struct StreamEvent: Decodable {
    let type: String?
    let diff: Bool?
    let payload: MediaPayload
}

private struct MediaPayload: Decodable {
    let bundleIdentifier: String?
    let playing: Bool?
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let elapsedTime: Double?
    let artworkData: String?
}
