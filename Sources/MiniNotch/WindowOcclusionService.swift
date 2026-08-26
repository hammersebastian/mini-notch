import AppKit
import ApplicationServices

private let windowOcclusionObserverCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }

    let service = Unmanaged<WindowOcclusionService>
        .fromOpaque(refcon)
        .takeUnretainedValue()

    Task { @MainActor in
        service.refresh()
    }
}

/// Prüft den Rahmen des fokussierten Fensters der Vordergrund-App. Das
/// Accessibility-API verwendet globale Bildschirmkoordinaten mit Ursprung oben
/// links; der Rahmen der MiniNotch wird vom Panel-Controller in dasselbe
/// Koordinatensystem übergeben.
@MainActor
final class WindowOcclusionService {
    var onStateChange: ((Bool, Bool) -> Void)?

    private struct State: Equatable {
        let hasAccessibilityPermission: Bool
        let isNotchCovered: Bool
    }

    private var notchFrame: CGRect?
    private var timer: Timer?
    private var lastState: State?
    private var observer: AXObserver?
    private var observedProcessIdentifier: pid_t?
    private var observedWindow: AXUIElement?
    private var workspaceObservers: [NSObjectProtocol] = []

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        ]

        refresh()
    }

    deinit {
        timer?.invalidate()

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceNotificationCenter.removeObserver)
    }

    func updateNotchFrame(_ frame: CGRect?) {
        notchFrame = frame
    }

    /// Fordert die Freigabe für genau die aktuell laufende App-Bundle-Instanz
    /// an. Das ist wichtig, weil Entwicklungs- und installierte Builds an
    /// unterschiedlichen Pfaden liegen können.
    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func refresh() {
        let hasAccessibilityPermission = AXIsProcessTrusted()

        guard hasAccessibilityPermission,
              let notchFrame,
              let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let focusedWindow = focusedWindow(for: frontmostApplication),
              let focusedWindowFrame = windowFrame(for: focusedWindow) else {
            removeObserver()
            publish(
                hasAccessibilityPermission: hasAccessibilityPermission,
                isNotchCovered: false
            )
            return
        }

        observe(
            processIdentifier: frontmostApplication.processIdentifier,
            window: focusedWindow
        )

        publish(
            hasAccessibilityPermission: hasAccessibilityPermission,
            isNotchCovered: focusedWindowFrame.intersects(notchFrame)
        )
    }

    private func focusedWindow(for application: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)

        guard let windowElement = windowElement(
            of: appElement,
            attribute: kAXFocusedWindowAttribute
        ) ?? windowElement(
            of: appElement,
            attribute: kAXMainWindowAttribute
        ) else { return nil }

        return windowElement
    }

    private func windowFrame(for window: AXUIElement) -> CGRect? {
        guard let position = pointValue(
            of: window,
            attribute: kAXPositionAttribute
        ),
        let size = sizeValue(
            of: window,
            attribute: kAXSizeAttribute
        ),
        size.width > 0,
        size.height > 0 else { return nil }

        return CGRect(origin: position, size: size)
    }

    private func observe(processIdentifier: pid_t, window: AXUIElement) {
        if observedProcessIdentifier != processIdentifier {
            removeObserver()

            var newObserver: AXObserver?
            guard AXObserverCreate(
                processIdentifier,
                windowOcclusionObserverCallback,
                &newObserver
            ) == .success,
            let newObserver else { return }

            observer = newObserver
            observedProcessIdentifier = processIdentifier
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(newObserver),
                .commonModes
            )

            let appElement = AXUIElementCreateApplication(processIdentifier)
            addNotification(kAXFocusedWindowChangedNotification, for: appElement)
            addNotification(kAXMainWindowChangedNotification, for: appElement)
        }

        guard observedWindow == nil || !CFEqual(observedWindow, window) else { return }

        observedWindow = window
        addNotification(kAXMovedNotification, for: window)
        addNotification(kAXResizedNotification, for: window)
        addNotification(kAXUIElementDestroyedNotification, for: window)
    }

    private func addNotification(_ notification: String, for element: AXUIElement) {
        guard let observer else { return }

        _ = AXObserverAddNotification(
            observer,
            element,
            notification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func removeObserver() {
        guard let observer else { return }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        self.observer = nil
        observedProcessIdentifier = nil
        observedWindow = nil
    }

    private func windowElement(of element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = attributeValue(of: element, attribute: attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func attributeValue(of element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value
    }

    private func pointValue(of element: AXUIElement, attribute: String) -> CGPoint? {
        guard let rawValue = attributeValue(of: element, attribute: attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        let value = unsafeBitCast(rawValue, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeValue(of element: AXUIElement, attribute: String) -> CGSize? {
        guard let rawValue = attributeValue(of: element, attribute: attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        let value = unsafeBitCast(rawValue, to: AXValue.self)
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func publish(hasAccessibilityPermission: Bool, isNotchCovered: Bool) {
        let state = State(
            hasAccessibilityPermission: hasAccessibilityPermission,
            isNotchCovered: isNotchCovered
        )
        guard lastState != state else { return }

        lastState = state
        onStateChange?(hasAccessibilityPermission, isNotchCovered)
    }
}
