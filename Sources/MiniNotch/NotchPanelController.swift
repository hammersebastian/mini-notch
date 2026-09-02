import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController {
    private let model: AppModel
    private let mediaService: MediaControlService
    private let volumeService: SystemVolumeService
    private let codexUsageService: CodexUsageService
    private let panel: NSPanel
    private let menuBarCoverPanel: NSPanel
    private let occlusionService = WindowOcclusionService()
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var pendingHoverExit: DispatchWorkItem?
    private lazy var panelAnimator = NotchPanelAnimator(panel: panel)

    private let hoverExitDelay: TimeInterval = 0.10

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
        menuBarCoverPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureMenuBarCoverPanel()
        configureView()
        configureObservers()
        configureMouseMonitoring()
        configureOcclusionMonitoring()
        updateFrame()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }

        pendingHoverExit?.cancel()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Die Anzeige soll nicht mit den Menüleisten-Items konkurrieren.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.animationBehavior = .none
        // Die Notch begleitet normale Spaces, darf aber nicht in den Space
        // einer fremden Vollbild-App wechseln. So bleiben etwa die Safari-
        // oder Browser-Bedienelemente im Vollbild vollständig erreichbar.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenNone]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
    }

    private func configureMenuBarCoverPanel() {
        // Der Bereich bleibt optisch vollständig transparent, fängt aber
        // weiterhin Mausklicks ab, damit die Menüleiste dort nicht reagiert.
        menuBarCoverPanel.isOpaque = false
        menuBarCoverPanel.backgroundColor = .clear
        menuBarCoverPanel.hasShadow = false
        // Das transparente Fenster liegt knapp über der macOS-Menüleiste. Es
        // nimmt Mausklicks entgegen, damit sich darunter keine Menüleiste
        // öffnen lässt, solange die Notch aufgeklappt ist.
        menuBarCoverPanel.level = NSWindow.Level(
            rawValue: NSWindow.Level.statusBar.rawValue + 1
        )
        menuBarCoverPanel.animationBehavior = .none
        menuBarCoverPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenNone]
        menuBarCoverPanel.hidesOnDeactivate = false
        menuBarCoverPanel.isMovable = false
        menuBarCoverPanel.isReleasedWhenClosed = false
        menuBarCoverPanel.becomesKeyOnlyIfNeeded = true
        menuBarCoverPanel.ignoresMouseEvents = false
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
        model.$isHovered
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
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

        model.activityManager.$currentActivityID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        model.$disabledNotchContents
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        model.$selectedDisplayID
            .removeDuplicates()
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

        model.$isCoveredByFrontmostWindow
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.model.refreshDisplayOptions()
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

    private func configureOcclusionMonitoring() {
        occlusionService.onStateChange = { [weak self] hasAccessibilityPermission, isNotchCovered in
            guard let self else { return }

            if model.hasAccessibilityPermission != hasAccessibilityPermission {
                model.hasAccessibilityPermission = hasAccessibilityPermission
            }

            if model.isCoveredByFrontmostWindow != isNotchCovered {
                model.isCoveredByFrontmostWindow = isNotchCovered
            }
        }
        occlusionService.start()
    }

    func requestAccessibilityPermission() {
        occlusionService.requestAccessibilityPermission()
    }

    private func updateHoverState() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = targetScreen() else { return }

        // Ist die Notch wegen eines überlagernden Vordergrundfensters komplett
        // ausgeblendet, existiert kein sichtbarer Panel-Rahmen als Hover-Zone.
        // In diesem Fall dient allein die tatsächliche Hardware-Notch als
        // unsichtbarer Hotspot, über den die Notch wieder aufgeklappt wird.
        let hoverFrame = panel.isVisible
            ? panel.frame
            : physicalNotchFrame(on: screen)

        // Die obere Kante der echten Notch liegt direkt am Bildschirmrand.
        // Erreicht der Zeiger exakt diese Kante (oder wechselt auf einen darüber
        // liegenden Monitor), liegt er technisch außerhalb des Panel-Frames und
        // die Notch würde sofort einklappen. Oberhalb des Panels bleibt die
        // Hover-Zone deshalb offen; seitlich und unterhalb gilt weiterhin der
        // normale Ausstieg.
        let isWithinHorizontalBounds =
            mouseLocation.x >= hoverFrame.minX && mouseLocation.x <= hoverFrame.maxX
        let isAtOrAbovePanel = mouseLocation.y >= hoverFrame.minY
        let isHoveringPanel = panel.isVisible && isWithinHorizontalBounds && isAtOrAbovePanel

        let isHoveringHotspot = !panel.isVisible && hoverFrame.contains(mouseLocation)
        let isHoveringNotch = isHoveringPanel || isHoveringHotspot

        if isHoveringNotch {
            pendingHoverExit?.cancel()
            pendingHoverExit = nil

            guard !model.isHovered else { return }
            model.isHovered = true
            return
        }

        guard model.isHovered, pendingHoverExit == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingHoverExit = nil
            self.model.isHovered = false
        }
        pendingHoverExit = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverExitDelay, execute: workItem)
    }

    private func updateFrame() {
        guard let screen = targetScreen() else { return }

        updatePhysicalNotchGeometry(screen: screen)

        // Ein Hover über die physische Notch darf die ansonsten wegen einer
        // Fensterüberdeckung ausgeblendete Ansicht gezielt wieder öffnen.
        let shouldDisplayPanel = model.shouldShowNotch || model.isHovered

        let presentation = model.presentation
        let size = panelSize(for: presentation, screen: screen)
        let frame = NSRect(
            x: notchCenterX(screen: screen) - size.width / 2,
            y: panelTopY(on: screen) - size.height,
            width: size.width,
            height: size.height
        )

        // Ausschlaggebend ist ausschließlich die eingeklappte Notch. Wenn
        // bereits sie ein aktives Fenster überdecken würde, wird MiniNotch
        // verborgen. Die aufgeklappte Ansicht beeinflusst diese Entscheidung
        // bewusst nicht.
        let collapsedSize = panelSize(for: .collapsed, screen: screen)
        let collapsedFrame = NSRect(
            x: notchCenterX(screen: screen) - collapsedSize.width / 2,
            y: panelTopY(on: screen) - collapsedSize.height,
            width: collapsedSize.width,
            height: collapsedSize.height
        )

        // Der gespeicherte Schutzbereich bleibt auch beim Ausblenden erhalten.
        // Dadurch kann die Prüfung feststellen, wann das Vordergrundfenster
        // nicht mehr über der Notch liegt und sie wieder erscheinen darf.
        occlusionService.updateNotchFrame(
            accessibilityFrame(for: collapsedFrame, on: screen)
        )
        occlusionService.refresh()

        guard shouldDisplayPanel else {
            if model.isHovered {
                model.isHovered = false
            }
            menuBarCoverPanel.orderOut(nil)

            if panel.isVisible {
                // Die Notch bleibt während der gemeinsamen Verkleinerungs- und
                // Ausblendbewegung auf der sichtbaren Ebene. Die Deckkraft
                // fällt erst im letzten Teil der Federbewegung ab, sodass weder
                // ein kompakter Zwischenstopp noch ein rechteckiger Endzustand
                // sichtbar wird.
                updatePanelLevel(for: .expanded)
                panelAnimator.animate(
                    to: physicalNotchFrame(on: screen),
                    alpha: 0,
                    fadeOutFrom: 0.72
                ) { [weak self] in
                    guard let self, !self.model.shouldShowNotch, !self.model.isHovered else {
                        self?.updateFrame()
                        return
                    }
                    self.panel.orderOut(nil)
                    self.updatePanelLevel(for: .collapsed)
                }
            } else {
                updatePanelLevel(for: .collapsed)
            }
            return
        }

        updatePanelLevel(for: presentation)
        updateMenuBarCover(for: presentation, notchFrame: frame, on: screen)

        if !panel.isVisible {
            panelAnimator.set(frame: physicalNotchFrame(on: screen), alpha: 0)
            panel.orderFrontRegardless()
            panelAnimator.animate(to: frame, alpha: 1)
        } else {
            panelAnimator.animate(to: frame, alpha: 1)
        }

        // Falls der Zeiger bereits an der Notch steht, muss die Ansicht direkt
        // aufklappen, auch wenn seit dem Einblenden kein Mausereignis ankommt.
        DispatchQueue.main.async { [weak self] in
            self?.updateHoverState()
        }
    }

    private func targetScreen() -> NSScreen? {
        if let selectedScreen = model.selectedScreen() {
            return selectedScreen
        }

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

    private func updatePhysicalNotchGeometry(screen: NSScreen) {
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            model.physicalNotchWidth = max(right.minX - left.maxX, 150)
        } else {
            model.physicalNotchWidth = 190
        }

        model.physicalNotchHeight = max(screen.safeAreaInsets.top, 30)
    }

    private func accessibilityFrame(for frame: NSRect, on screen: NSScreen) -> CGRect {
        let displayID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
        let displayFrame = displayID.map(CGDisplayBounds) ?? .zero

        return CGRect(
            x: displayFrame.minX + (frame.minX - screen.frame.minX),
            y: displayFrame.minY + (screen.frame.maxY - frame.maxY),
            width: frame.width,
            height: frame.height
        )
    }

    private func panelTopY(on screen: NSScreen) -> CGFloat {
        // Die Oberfläche beginnt direkt an der oberen Bildschirmkante und
        // verbindet sich dadurch ohne sichtbare Stufe mit der Hardware-Notch.
        screen.frame.maxY
    }

    private func physicalNotchFrame(on screen: NSScreen) -> NSRect {
        NSRect(
            x: notchCenterX(screen: screen) - model.physicalNotchWidth / 2,
            y: panelTopY(on: screen) - model.physicalNotchHeight,
            width: model.physicalNotchWidth,
            height: model.physicalNotchHeight
        )
    }

    private func updatePanelLevel(for presentation: NotchPresentation) {
        if presentation == .expanded {
            // Der sichtbare Notch-Inhalt bleibt über der Abdeckung, die selbst
            // wiederum die Menüleiste verdeckt.
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        } else {
            // Im eingeklappten Zustand haben die macOS-Menüleisten-Items wie
            // bisher stets Vorrang.
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        }
    }

    private func updateMenuBarCover(
        for presentation: NotchPresentation,
        notchFrame: NSRect,
        on screen: NSScreen
    ) {
        guard presentation == .expanded else {
            menuBarCoverPanel.orderOut(nil)
            return
        }

        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        let frame = NSRect(
            x: notchFrame.minX,
            y: screen.frame.maxY - menuBarHeight,
            width: notchFrame.width,
            height: menuBarHeight
        )

        menuBarCoverPanel.setFrame(frame, display: true)
        menuBarCoverPanel.orderFrontRegardless()
    }

    private func notchCenterX(screen: NSScreen) -> CGFloat {
        // Die beiden Safe-Areas können durch Pixelrundung unterschiedlich
        // breit sein. Auf dem internen MacBook-Display lag ihre gemittelte
        // Mitte dadurch 1,5 pt (3 Pixel) neben der realen Hardware-Notch.
        // Die Notch selbst sitzt immer in der geometrischen Bildschirmmitte.
        return screen.frame.midX
    }

    private func panelSize(for presentation: NotchPresentation, screen: NSScreen) -> NSSize {
        let notch = model.physicalNotchWidth
        let maximumWidth = max(480, screen.frame.width - 40)

        switch presentation {
        case .collapsed:
            return NSSize(
                // 185 pt entsprechen auf dem Retina-Display 370 Pixeln und
                // damit der Breite der physischen MacBook-Notch.
                width: 185,
                height: max(model.physicalNotchHeight + 38, 68)
            )

        case .expanded:
            let standardExpandedHeight = max(model.physicalNotchHeight + 190, 226)
            // Die Mediensteuerung enthält zusätzlich zum Kopfbereich Album,
            // Transporttasten und Lautstärkeregler. Nach dem neuen
            // Notch-Übergang ist ihr oberer Freiraum größer; ohne diese Höhe
            // würde der Regler am unteren Rand anliegen.
            let mediaControlsHeight: CGFloat = model.notchContent == .media ? 20 : 0
            let expandedHeight = standardExpandedHeight + mediaControlsHeight

            return NSSize(
                width: min(max(notch + 440, 600), maximumWidth),
                height: expandedHeight
            )
        }
    }
}
