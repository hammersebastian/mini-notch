import AppKit
import SwiftUI

/// Gemeinsame Bewegungsparameter für Form, Inhalt und Fenster. Alle Teile der
/// Notch reagieren damit wie ein zusammenhängendes, unterbrechbares Element.
enum NotchMotion {
    static let response: TimeInterval = 0.44
    static let dampingRatio: CGFloat = 0.86
    static let maximumDuration: TimeInterval = 0.72

    static var spring: Animation {
        .spring(
            response: response,
            dampingFraction: dampingRatio,
            blendDuration: 0
        )
    }

    static let reducedMotion = Animation.easeOut(duration: 0.12)
}

/// Animiert den echten Panel-Rahmen mit derselben Feder wie SwiftUI. Im
/// Gegensatz zu NSAnimationContext kann die Bewegung jederzeit auf ein neues
/// Ziel umgelenkt werden, ohne zuerst zur alten Zielgröße zu springen.
@MainActor
final class NotchPanelAnimator {
    private weak var panel: NSPanel?
    private var timer: Timer?
    private var lastTimestamp: TimeInterval?
    private var animationStartedAt: TimeInterval = 0
    private var completion: (() -> Void)?

    private var x = SpringValue()
    private var y = SpringValue()
    private var width = SpringValue()
    private var height = SpringValue()
    private var alpha = SpringValue()

    private var targetFrame = NSRect.zero
    private var targetAlpha: CGFloat = 1
    private var fadeOutStartProgress: CGFloat?
    private var fadeStartHeight: CGFloat = 0
    private var fadeStartAlpha: CGFloat = 1
    private var maximumFrameProgress: CGFloat = 0

    init(panel: NSPanel) {
        self.panel = panel
        synchronizeWithPanel()
    }

    func set(frame: NSRect, alpha targetAlpha: CGFloat = 1) {
        stop(callCompletion: false)
        targetFrame = frame
        self.targetAlpha = targetAlpha
        fadeOutStartProgress = nil
        apply(frame: frame, alpha: targetAlpha)
        synchronizeWithPanel()
    }

    func animate(
        to frame: NSRect,
        alpha targetAlpha: CGFloat = 1,
        fadeOutFrom fadeOutStartProgress: CGFloat? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard panel != nil else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            set(frame: frame, alpha: targetAlpha)
            completion?()
            return
        }

        let normalizedFadeStart = fadeOutStartProgress.map {
            min(max($0, 0), 0.99)
        }
        let fadeBehaviorChanged = self.fadeOutStartProgress != normalizedFadeStart
        let targetChanged = !targetFrame.isApproximatelyEqual(to: frame) ||
            abs(self.targetAlpha - targetAlpha) > 0.001
        let isStartingAnimation = timer == nil

        if isStartingAnimation {
            synchronizeWithPanel()
            animationStartedAt = ProcessInfo.processInfo.systemUptime
            lastTimestamp = nil
        } else if targetChanged || fadeBehaviorChanged {
            // Bei einer Umkehr beginnt nur das Zeitlimit neu. Position und
            // Geschwindigkeit bleiben erhalten und gehen nahtlos weiter.
            animationStartedAt = ProcessInfo.processInfo.systemUptime
        }

        if isStartingAnimation || targetChanged || fadeBehaviorChanged {
            fadeStartHeight = height.value
            fadeStartAlpha = alpha.value
            maximumFrameProgress = 0

            // Der verzögerte Fade wird direkt aus dem Fortschritt der
            // Rahmenanimation abgeleitet. Eine alte Alpha-Geschwindigkeit darf
            // beim Wechsel der Strategie nicht in die neue Bewegung hineinwirken.
            if normalizedFadeStart != nil || self.fadeOutStartProgress != nil {
                alpha.velocity = 0
            }
        }

        targetFrame = frame
        self.targetAlpha = targetAlpha
        self.fadeOutStartProgress = normalizedFadeStart
        self.completion = completion

        guard !isSettled else {
            apply(frame: frame, alpha: targetAlpha)
            stop(callCompletion: true)
            return
        }

        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tick()
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop(callCompletion: Bool = false) {
        timer?.invalidate()
        timer = nil
        lastTimestamp = nil

        let pendingCompletion = completion
        completion = nil
        if callCompletion {
            pendingCompletion?()
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = lastTimestamp.map { min(max(now - $0, 0), 1.0 / 20.0) } ?? (1.0 / 120.0)
        lastTimestamp = now

        // Kleine feste Schritte halten die Feder auch dann stabil, wenn der
        // Main RunLoop für einen Moment durch Layout-Arbeit beschäftigt war.
        let stepSize = 1.0 / 120.0
        var remaining = elapsed
        while remaining > 0 {
            let delta = min(remaining, stepSize)
            integrate(deltaTime: delta)
            remaining -= delta
        }

        applyDelayedFadeIfNeeded()

        let frame = NSRect(x: x.value, y: y.value, width: width.value, height: height.value)
        apply(frame: frame, alpha: min(max(alpha.value, 0), 1))

        if isSettled || now - animationStartedAt >= NotchMotion.maximumDuration {
            apply(frame: targetFrame, alpha: targetAlpha)
            synchronizeWithPanel()
            stop(callCompletion: true)
        }
    }

    private func integrate(deltaTime: TimeInterval) {
        let angularFrequency = 2 * Double.pi / NotchMotion.response
        let stiffness = angularFrequency * angularFrequency
        let damping = 2 * Double(NotchMotion.dampingRatio) * angularFrequency

        x.integrate(towards: targetFrame.origin.x, stiffness: stiffness, damping: damping, deltaTime: deltaTime)
        y.integrate(towards: targetFrame.origin.y, stiffness: stiffness, damping: damping, deltaTime: deltaTime)
        width.integrate(towards: targetFrame.width, stiffness: stiffness, damping: damping, deltaTime: deltaTime)
        height.integrate(towards: targetFrame.height, stiffness: stiffness, damping: damping, deltaTime: deltaTime)
        if fadeOutStartProgress == nil {
            alpha.integrate(towards: targetAlpha, stiffness: stiffness, damping: damping, deltaTime: deltaTime)
        }
    }

    private func applyDelayedFadeIfNeeded() {
        guard let fadeOutStartProgress else { return }

        let totalDistance = abs(fadeStartHeight - targetFrame.height)
        let currentProgress: CGFloat
        if totalDistance <= 0.001 {
            currentProgress = 1
        } else {
            currentProgress = 1 - abs(height.value - targetFrame.height) / totalDistance
        }

        // Eine leicht überschwingende Feder darf die Deckkraft nicht wieder
        // erhöhen, nachdem das Panel bereits in der Hardware-Notch verschwindet.
        maximumFrameProgress = max(maximumFrameProgress, min(max(currentProgress, 0), 1))

        let fadeProgress = min(
            max((maximumFrameProgress - fadeOutStartProgress) / (1 - fadeOutStartProgress), 0),
            1
        )
        let easedFadeProgress = fadeProgress * fadeProgress * (3 - 2 * fadeProgress)
        alpha.value = fadeStartAlpha + (targetAlpha - fadeStartAlpha) * easedFadeProgress
        alpha.velocity = 0
    }

    private var isSettled: Bool {
        x.isSettled(at: targetFrame.origin.x) &&
            y.isSettled(at: targetFrame.origin.y) &&
            width.isSettled(at: targetFrame.width) &&
            height.isSettled(at: targetFrame.height) &&
            alpha.isSettled(at: targetAlpha, valueTolerance: 0.002, velocityTolerance: 0.02)
    }

    private func apply(frame: NSRect, alpha: CGFloat) {
        panel?.setFrame(frame, display: true)
        panel?.alphaValue = alpha
    }

    private func synchronizeWithPanel() {
        guard let panel else { return }

        x = SpringValue(value: panel.frame.origin.x)
        y = SpringValue(value: panel.frame.origin.y)
        width = SpringValue(value: panel.frame.width)
        height = SpringValue(value: panel.frame.height)
        alpha = SpringValue(value: panel.alphaValue)
    }
}

private struct SpringValue {
    var value: CGFloat = 0
    var velocity: CGFloat = 0

    mutating func integrate(
        towards target: CGFloat,
        stiffness: Double,
        damping: Double,
        deltaTime: TimeInterval
    ) {
        let displacement = Double(value - target)
        let acceleration = -stiffness * displacement - damping * Double(velocity)
        velocity += CGFloat(acceleration * deltaTime)
        value += velocity * CGFloat(deltaTime)
    }

    func isSettled(
        at target: CGFloat,
        valueTolerance: CGFloat = 0.12,
        velocityTolerance: CGFloat = 0.8
    ) -> Bool {
        abs(value - target) <= valueTolerance && abs(velocity) <= velocityTolerance
    }
}

private extension NSRect {
    func isApproximatelyEqual(to other: NSRect) -> Bool {
        abs(origin.x - other.origin.x) <= 0.01 &&
            abs(origin.y - other.origin.y) <= 0.01 &&
            abs(width - other.width) <= 0.01 &&
            abs(height - other.height) <= 0.01
    }
}
