import AppKit
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configureMedia()
        configureCodexUsage()
        configureNotch()
        configureMenuBar()

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
        item.button?.image = menuBarIcon()
        item.button?.imageScaling = .scaleProportionallyDown

        let menu = NSMenu()

        let settings = NSMenuItem(
            title: "Einstellungen …",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "MiniNotch stoppen",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func menuBarIcon() -> NSImage? {
        guard
            let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    @objc
    private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: SettingsView(
                model: model,
                requestAccessibilityPermission: { [weak self] in
                    self?.notchController?.requestAccessibilityPermission()
                }
            )
        )
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
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
