import ApplicationServices
import Foundation

enum MouseJigglerStartResult: Equatable {
    case started
    case alreadyRunning
    case accessibilityPermissionRequired
}

/// Bewegt den Zeiger in festen Abständen und führt anschließend einen
/// Rechtsklick aus. Die Eingabeereignisse werden ausschließlich über die
/// öffentliche CoreGraphics-API erzeugt.
@MainActor
final class MouseJigglerService: ObservableObject {
    static let interval: TimeInterval = 20
    static let movementDuration: TimeInterval = 0.8

    @Published private(set) var isRunning = false

    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibilityPermission: () -> Void
    private var jiggleTask: Task<Void, Never>?

    init(
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        requestAccessibilityPermission: @escaping () -> Void = {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityPermission = requestAccessibilityPermission
    }

    deinit {
        jiggleTask?.cancel()
    }

    @discardableResult
    func start() -> MouseJigglerStartResult {
        guard isAccessibilityTrusted() else {
            requestAccessibilityPermission()
            return .accessibilityPermissionRequired
        }

        guard !isRunning else { return .alreadyRunning }

        isRunning = true
        jiggleTask = Task { [weak self] in
            await self?.run()
        }
        return .started
    }

    func stop() {
        jiggleTask?.cancel()
        jiggleTask = nil
        isRunning = false
    }

    private func run() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(Self.interval))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await moveAndRightClick()
        }
    }

    private func moveAndRightClick() async {
        guard let start = CGEvent(source: nil)?.location else {
            stop()
            return
        }

        let target = randomPointInSafeArea()
        let steps = max(1, Int(Self.movementDuration * 60))

        for step in 1...steps {
            guard !Task.isCancelled else { return }

            let progress = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: start.x + (target.x - start.x) * progress,
                y: start.y + (target.y - start.y) * progress
            )
            postMouseEvent(.mouseMoved, at: point, button: .left)

            do {
                try await Task.sleep(for: .seconds(Self.movementDuration / Double(steps)))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        postMouseEvent(.rightMouseDown, at: target, button: .right)

        do {
            try await Task.sleep(for: .milliseconds(80))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        postMouseEvent(.rightMouseUp, at: target, button: .right)
    }

    private func randomPointInSafeArea() -> CGPoint {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let horizontalRange = (bounds.minX + bounds.width / 4)...(bounds.minX + bounds.width * 3 / 4)
        let verticalRange = (bounds.minY + bounds.height / 4)...(bounds.minY + bounds.height * 3 / 4)

        return CGPoint(
            x: CGFloat.random(in: horizontalRange),
            y: CGFloat.random(in: verticalRange)
        )
    }

    private func postMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton
    ) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        )
        event?.post(tap: .cghidEventTap)
    }
}
