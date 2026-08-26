import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let mediaService = MediaControlService()
    private let volumeService = SystemVolumeService()
    private let codexUsageService = CodexUsageService()

    private var notchController: NotchPanelController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var mediaStatusItem: NSMenuItem?
    private var codexStatusItem: NSMenuItem?
    private var diagnosticsItem: NSMenuItem?
    private var mediaContentItem: NSMenuItem?
    private var codexContentItem: NSMenuItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configureMedia()
        configureCodexUsage()
        configureNotch()
        configureMenuBar()
        configureDiagnostics()

        volumeService.readVolume { [weak self] volume in
            if let volume {
                self?.model.systemVolume = volume
            }
        }

        mediaService.start()
        codexUsageService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService.stop()
        codexUsageService.stop()
    }

    private func configureMedia() {
        mediaService.onStateUpdate = { [weak self] state in
            self?.model.updateMedia(state)
        }

        mediaService.onError = { [weak self] error in
            self?.model.lastError = error
            print("MiniNotch: \(error)")
        }
    }

    private func configureNotch() {
        notchController = NotchPanelController(
            model: model,
            mediaService: mediaService,
            volumeService: volumeService,
            codexUsageService: codexUsageService
        )
    }

    private func configureCodexUsage() {
        codexUsageService.onStateUpdate = { [weak self] usage in
            self?.model.updateCodexUsage(usage)
        }
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "MiniNotch"
        )

        let menu = NSMenu()

        let mediaStatus = NSMenuItem(title: "Medien: Suche nach Wiedergabe …", action: nil, keyEquivalent: "")
        mediaStatus.isEnabled = false
        menu.addItem(mediaStatus)
        mediaStatusItem = mediaStatus

        let codexStatus = NSMenuItem(title: "Codex: Limits werden geladen …", action: nil, keyEquivalent: "")
        codexStatus.isEnabled = false
        menu.addItem(codexStatus)
        codexStatusItem = codexStatus

        let diagnostics = NSMenuItem(title: "Status: wird gestartet …", action: nil, keyEquivalent: "")
        diagnostics.isEnabled = false
        menu.addItem(diagnostics)
        diagnosticsItem = diagnostics

        menu.addItem(.separator())

        let display = NSMenuItem(title: "Notch-Anzeige", action: nil, keyEquivalent: "")
        display.isEnabled = false
        menu.addItem(display)

        let mediaContent = NSMenuItem(
            title: "Medien anzeigen",
            action: #selector(showMediaContent),
            keyEquivalent: ""
        )
        mediaContent.target = self
        menu.addItem(mediaContent)
        mediaContentItem = mediaContent

        let codexContent = NSMenuItem(
            title: "Codex-Limits anzeigen",
            action: #selector(showCodexContent),
            keyEquivalent: ""
        )
        codexContent.target = self
        menu.addItem(codexContent)
        codexContentItem = codexContent

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Einstellungen …",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let restartMedia = NSMenuItem(
            title: "Medienerkennung neu starten",
            action: #selector(restartMediaService),
            keyEquivalent: "r"
        )
        restartMedia.target = self
        menu.addItem(restartMedia)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "MiniNotch beenden",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func configureDiagnostics() {
        model.$media
            .receive(on: RunLoop.main)
            .sink { [weak self] media in
                if media.hasMedia {
                    self?.mediaStatusItem?.title = "Medien: \(media.title)"
                    self?.diagnosticsItem?.title = "Status: Wiedergabe empfangen"
                } else {
                    self?.mediaStatusItem?.title = "Medien: Suche nach Wiedergabe …"
                }
            }
            .store(in: &cancellables)

        model.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if let error {
                    self?.diagnosticsItem?.title = "Status: \(error)"
                }
            }
            .store(in: &cancellables)

        model.$codexUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] usage in
                switch usage.state {
                case .loading:
                    self?.codexStatusItem?.title = "Codex: Limits werden geladen …"
                case .available:
                    let fiveHours = usage.primaryWindow?.percentageText ?? "—"
                    let weekly = usage.weeklyWindow?.percentageText ?? "—"
                    self?.codexStatusItem?.title = "Codex: 5 Std. \(fiveHours) · Woche \(weekly)"
                case .unavailable:
                    self?.codexStatusItem?.title = "Codex: Limits nicht verfügbar"
                }
            }
            .store(in: &cancellables)

        model.$notchContent
            .receive(on: RunLoop.main)
            .sink { [weak self] content in
                self?.mediaContentItem?.state = content == .media ? .on : .off
                self?.codexContentItem?.state = content == .codexUsage ? .on : .off
                self?.statusItem?.button?.image = NSImage(
                    systemSymbolName: content == .media ? "music.note" : "chevron.left.forwardslash.chevron.right",
                    accessibilityDescription: "MiniNotch"
                )
            }
            .store(in: &cancellables)
    }

    @objc
    private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: controller)
        window.title = "MiniNotch Einstellungen"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func restartMediaService() {
        model.lastError = nil
        mediaService.start()
    }

    @objc
    private func showMediaContent() {
        model.notchContent = .media
    }

    @objc
    private func showCodexContent() {
        model.notchContent = .codexUsage
        codexUsageService.refresh()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
