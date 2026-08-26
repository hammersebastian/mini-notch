import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class NotchPanelController {
    private let model: AppModel
    private let mediaService: MediaControlService
    private let volumeService: SystemVolumeService
    private let codexUsageService: CodexUsageService
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var displayedPresentation: NotchPresentation?

    // Die kurze Ease-out-Kurve lässt die Notch direkt reagieren, ohne dass der
    // Größenwechsel beim Hover hart in den Bildschirm springt.
    private let presentationAnimationDuration: TimeInterval = 0.26

    init(
        model: AppModel,
        mediaService: MediaControlService,
        volumeService: SystemVolumeService,
        codexUsageService: CodexUsageService
    ) {
        self.model = model
        self.mediaService = mediaService
        self.volumeService = volumeService
        self.codexUsageService = codexUsageService

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureView()
        configureObservers()
        configureMouseMonitoring()
        updateFrame()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Die Anzeige soll nicht mit den Menüleisten-Items konkurrieren.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
    }

    private func configureView() {
        let hostingView = NSHostingView(
            rootView: NotchView(
                model: model,
                mediaService: mediaService,
                volumeService: volumeService,
                codexUsageService: codexUsageService
            )
        )

        // Die Panel-Geometrie wird ausschließlich in `updateFrame` gesteuert.
        // Die Standardoptionen von NSHostingView versuchen sonst gleichzeitig,
        // das Fenster aus der SwiftUI-Inhaltsgröße zu skalieren. Das führte bei
        // einer Änderung der Präsentation zu einer Layout-Endlosschleife.
        hostingView.sizingOptions = []
        // Das Panel wird absichtlich direkt an der oberen Bildschirmkante
        // platziert. Die dynamischen Safe-Area-Ecken des Fensters dürfen dabei
        // nicht erneut eine SwiftUI-Layoutberechnung des Fensters auslösen.
        hostingView.safeAreaRegions = []
        panel.contentView = hostingView
    }

    private func configureObservers() {
        Publishers.CombineLatest(model.$isHovered, model.$isPeeking)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        // `media-control stream --no-diff` liefert auch bei unverändertem Titel
        // regelmäßig neue Payloads. Die Ansicht aktualisiert ihren Inhalt selbst;
        // das Fenster muss nur bei Ein-/Ausblenden neu positioniert werden.
        model.$media
            .map(\.hasMedia)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        model.$notchContent
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        model.$codexUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)
    }

    /// Das Panel liegt über der Menüleiste. SwiftUIs `onHover` bekommt dort nicht
    /// in jeder Konstellation Enter-/Exit-Ereignisse. Die globale Mausüberwachung
    /// prüft deshalb die tatsächliche Zeigerposition gegen den Panel-Rahmen.
    private func configureMouseMonitoring() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateHoverState()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.updateHoverState()
            return event
        }
    }

    private func updateHoverState() {
        let mouseLocation = NSEvent.mouseLocation
        let panelFrame = panel.frame

        // Die obere Kante der echten Notch liegt direkt am Bildschirmrand.
        // Erreicht der Zeiger exakt diese Kante (oder wechselt auf einen darüber
        // liegenden Monitor), liegt er technisch außerhalb des Panel-Frames und
        // die Notch würde sofort einklappen. Oberhalb des Panels bleibt die
        // Hover-Zone deshalb offen; seitlich und unterhalb gilt weiterhin der
        // normale Ausstieg.
        let isWithinHorizontalBounds =
            mouseLocation.x >= panelFrame.minX && mouseLocation.x <= panelFrame.maxX
        let isAtOrAbovePanel = mouseLocation.y >= panelFrame.minY
        let isHoveringPanel = panel.isVisible && isWithinHorizontalBounds && isAtOrAbovePanel

        guard model.isHovered != isHoveringPanel else { return }
        model.isHovered = isHoveringPanel
    }

    private func updateFrame() {
        guard let screen = targetScreen() else { return }

        updatePhysicalNotchGeometry(screen: screen)
        updatePanelLevel(for: screen)

        guard model.shouldShowNotch else {
            if model.isHovered {
                model.isHovered = false
            }
            panel.orderOut(nil)
            return
        }

        let presentation = model.presentation
        let size = panelSize(for: presentation, screen: screen)
        let centerX = notchCenterX(screen: screen)
        let frame = NSRect(
            x: centerX - size.width / 2,
            y: panelTopY(on: screen) - size.height,
            width: size.width,
            height: size.height
        )

        if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        } else if displayedPresentation != presentation {
            animatePanel(to: frame)
        } else {
            panel.setFrame(frame, display: true)
        }

        displayedPresentation = presentation

        // Falls der Zeiger bereits an der Notch steht, muss die Ansicht direkt
        // aufklappen, auch wenn seit dem Einblenden kein Mausereignis ankommt.
        DispatchQueue.main.async { [weak self] in
            self?.updateHoverState()
        }
    }

    private func targetScreen() -> NSScreen? {
        let screenWithNotch = NSScreen.screens.first {
            $0.safeAreaInsets.top > 0 &&
            $0.auxiliaryTopLeftArea != nil &&
            $0.auxiliaryTopRightArea != nil
        }

        let screenUnderPointer = NSScreen.screens.first {
            $0.frame.contains(NSEvent.mouseLocation)
        }

        return screenWithNotch ?? screenUnderPointer ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func animatePanel(to frame: NSRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = presentationAnimationDuration
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.22,
                1.0,
                0.36,
                1.0
            )
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func updatePhysicalNotchGeometry(screen: NSScreen) {
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            model.physicalNotchWidth = max(right.minX - left.maxX, 150)
        } else {
            model.physicalNotchWidth = 190
        }

        model.physicalNotchHeight = max(screen.safeAreaInsets.top, 30)
    }

    private func panelTopY(on screen: NSScreen) -> CGFloat {
        // Die Oberfläche beginnt direkt an der oberen Bildschirmkante und
        // verbindet sich dadurch ohne sichtbare Stufe mit der Hardware-Notch.
        screen.frame.maxY
    }

    private func updatePanelLevel(for screen: NSScreen) {
        // Die Menüleiste hat stets Vorrang vor MiniNotch, auch im Bereich der
        // transparenten seitlichen Flächen des rechteckigen Panel-Fensters.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
    }

    private func notchCenterX(screen: NSScreen) -> CGFloat {
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return (left.maxX + right.minX) / 2
        }

        return screen.frame.midX
    }

    private func panelSize(for presentation: NotchPresentation, screen: NSScreen) -> NSSize {
        let notch = model.physicalNotchWidth
        let maximumWidth = max(480, screen.frame.width - 40)

        switch presentation {
        case .collapsed:
            let defaultCollapsedWidth = min(max(notch + 300, 480), maximumWidth)

            return NSSize(
                width: defaultCollapsedWidth * 0.5,
                height: max(model.physicalNotchHeight + 38, 68)
            )

        case .trackPeek:
            return NSSize(
                width: min(max(notch + 470, 620), maximumWidth),
                height: 82
            )

        case .expanded:
            let expandedHeight = max(model.physicalNotchHeight + 190, 226)

            return NSSize(
                width: min(max(notch + 440, 600), maximumWidth),
                height: expandedHeight
            )
        }
    }
}
