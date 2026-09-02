import AudioToolbox
import CoreAudio
import Foundation

struct SystemVolumeSnapshot: Equatable {
    let normalizedVolume: Double
    let isMuted: Bool

    init(normalizedVolume: Double, isMuted: Bool) {
        self.normalizedVolume = min(max(normalizedVolume, 0), 1)
        self.isMuted = isMuted
    }
}

/// Beobachtet die öffentlichen Core-Audio-Properties für Lautstärke und Mute.
/// Das native macOS Volume HUD lässt sich über diese API nur beobachten, nicht
/// unterdrücken; dafür stellt macOS keine öffentliche, unterstützte API bereit.
final class SystemVolumeService {
    var onStateChange: ((SystemVolumeSnapshot) -> Void)?

    private let eventQueue = DispatchQueue(label: "MiniNotch.SystemVolumeService")
    private var isRunning = false
    private var observedDeviceID = kAudioObjectUnknown
    private var observedVolumeAddresses: [AudioObjectPropertyAddress] = []
    private var observedMuteAddresses: [AudioObjectPropertyAddress] = []
    private var registeredStateAddresses: [AudioObjectPropertyAddress] = []
    private var lastKnownState: SystemVolumeSnapshot?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var stateListener: AudioObjectPropertyListenerBlock?

    func start() {
        eventQueue.async { [weak self] in
            self?.startObserving()
        }
    }

    func stop() {
        eventQueue.sync {
            stopObserving()
        }
    }

    func readState(completion: @escaping (SystemVolumeSnapshot?) -> Void) {
        eventQueue.async {
            let state = Self.readDefaultOutputState()
            DispatchQueue.main.async {
                completion(state)
            }
        }
    }

    func setVolume(_ normalizedValue: Double) {
        let percent = Int((min(max(normalizedValue, 0), 1) * 100).rounded())
        DispatchQueue.global(qos: .utility).async {
            _ = Self.runAppleScript("set volume output volume \(percent)")
        }
    }

    deinit {
        stop()
    }

    private func startObserving() {
        guard !isRunning else { return }
        isRunning = true

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.replaceObservedOutputDevice()
        }
        var address = Self.defaultOutputDeviceAddress

        if AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            eventQueue,
            listener
        ) == noErr {
            defaultDeviceListener = listener
        }

        // Das Einlesen hier dient nur als Vergleichsbasis. Beim Start wird
        // absichtlich kein Change-Callback und damit keine Activity ausgelöst.
        replaceObservedOutputDevice()
    }

    private func stopObserving() {
        guard isRunning else { return }
        isRunning = false

        removeStateListeners()

        if let defaultDeviceListener {
            var address = Self.defaultOutputDeviceAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                eventQueue,
                defaultDeviceListener
            )
        }

        defaultDeviceListener = nil
        lastKnownState = nil
    }

    private func replaceObservedOutputDevice() {
        removeStateListeners()

        guard isRunning,
              let deviceID = Self.defaultOutputDeviceID() else {
            lastKnownState = nil
            return
        }

        observedDeviceID = deviceID
        observedVolumeAddresses = Self.volumeAddresses(for: deviceID)
        observedMuteAddresses = Self.muteAddresses(for: deviceID)
        lastKnownState = Self.readState(
            from: deviceID,
            volumeAddresses: observedVolumeAddresses,
            muteAddresses: observedMuteAddresses
        )

        guard !observedVolumeAddresses.isEmpty else { return }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleStateChange()
        }
        stateListener = listener

        registeredStateAddresses = (
            observedVolumeAddresses + observedMuteAddresses
        ).filter { address in
            var mutableAddress = address
            return AudioObjectAddPropertyListenerBlock(
                deviceID,
                &mutableAddress,
                eventQueue,
                listener
            ) == noErr
        }
    }

    private func removeStateListeners() {
        if let stateListener, observedDeviceID != kAudioObjectUnknown {
            for address in registeredStateAddresses {
                var mutableAddress = address
                AudioObjectRemovePropertyListenerBlock(
                    observedDeviceID,
                    &mutableAddress,
                    eventQueue,
                    stateListener
                )
            }
        }

        stateListener = nil
        observedVolumeAddresses = []
        observedMuteAddresses = []
        registeredStateAddresses = []
        observedDeviceID = kAudioObjectUnknown
    }

    private func handleStateChange() {
        guard isRunning,
              observedDeviceID != kAudioObjectUnknown,
              let state = Self.readState(
                from: observedDeviceID,
                volumeAddresses: observedVolumeAddresses,
                muteAddresses: observedMuteAddresses
              ) else {
            return
        }

        guard lastKnownState.map({ previousState in
            previousState.isMuted != state.isMuted
                || abs(previousState.normalizedVolume - state.normalizedVolume) > 0.000_1
        }) ?? true else {
            return
        }

        lastKnownState = state
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }

    private static var defaultOutputDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = defaultOutputDeviceAddress
        var deviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func readDefaultOutputState() -> SystemVolumeSnapshot? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }
        return readState(
            from: deviceID,
            volumeAddresses: volumeAddresses(for: deviceID),
            muteAddresses: muteAddresses(for: deviceID)
        )
    }

    private static func volumeAddresses(
        for deviceID: AudioDeviceID
    ) -> [AudioObjectPropertyAddress] {
        let virtualMain = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableVirtualMain = virtualMain
        if AudioObjectHasProperty(deviceID, &mutableVirtualMain) {
            return [virtualMain]
        }

        let main = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableMain = main
        if AudioObjectHasProperty(deviceID, &mutableMain) {
            return [main]
        }

        return [1, 2].compactMap { element in
            let address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element)
            )
            var mutableAddress = address
            return AudioObjectHasProperty(deviceID, &mutableAddress) ? address : nil
        }
    }

    private static func muteAddresses(
        for deviceID: AudioDeviceID
    ) -> [AudioObjectPropertyAddress] {
        let main = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableMain = main
        if AudioObjectHasProperty(deviceID, &mutableMain) {
            return [main]
        }

        // Ohne Main-Control gilt der Ausgang nur dann als vollständig stumm,
        // wenn alle verfügbaren beobachteten Ausgangskanäle stumm sind.
        return [1, 2].compactMap { element in
            let address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element)
            )
            var mutableAddress = address
            return AudioObjectHasProperty(deviceID, &mutableAddress) ? address : nil
        }
    }

    private static func readState(
        from deviceID: AudioDeviceID,
        volumeAddresses: [AudioObjectPropertyAddress],
        muteAddresses: [AudioObjectPropertyAddress]
    ) -> SystemVolumeSnapshot? {
        guard let volume = readVolume(
            from: deviceID,
            addresses: volumeAddresses
        ) else {
            return nil
        }

        return SystemVolumeSnapshot(
            normalizedVolume: volume,
            // Geräte ohne öffentlich zugängliche Mute-Property können nur
            // über ihren Lautstärkewert dargestellt werden. Insbesondere
            // bleibt ein ungemuteter Wert von null dadurch eine 0-%-Anzeige.
            isMuted: readMute(from: deviceID, addresses: muteAddresses) ?? false
        )
    }

    private static func readVolume(
        from deviceID: AudioDeviceID,
        addresses: [AudioObjectPropertyAddress]
    ) -> Double? {
        let values = addresses.compactMap { address -> Double? in
            var mutableAddress = address
            var value: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(
                deviceID,
                &mutableAddress,
                0,
                nil,
                &dataSize,
                &value
            )

            guard status == noErr else { return nil }
            return min(max(Double(value), 0), 1)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func readMute(
        from deviceID: AudioDeviceID,
        addresses: [AudioObjectPropertyAddress]
    ) -> Bool? {
        guard !addresses.isEmpty else { return nil }

        let values = addresses.compactMap { address -> Bool? in
            var mutableAddress = address
            var value: UInt32 = 0
            var dataSize = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(
                deviceID,
                &mutableAddress,
                0,
                nil,
                &dataSize,
                &value
            )

            guard status == noErr else { return nil }
            return value != 0
        }

        guard values.count == addresses.count else { return nil }
        return values.allSatisfy { $0 }
    }

    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
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
