import Testing
@testable import MiniNotch

@MainActor
struct MouseJigglerServiceTests {
    @Test
    func startRequestsAccessibilityPermissionWhenNeeded() {
        let requestSpy = PermissionRequestSpy()
        let service = MouseJigglerService(
            isAccessibilityTrusted: { false },
            requestAccessibilityPermission: { requestSpy.wasCalled = true }
        )

        #expect(service.start() == .accessibilityPermissionRequired)
        #expect(requestSpy.wasCalled)
        #expect(!service.isRunning)
    }

    @Test
    func startAndStopUpdateRunningState() {
        let service = MouseJigglerService(
            isAccessibilityTrusted: { true },
            requestAccessibilityPermission: {}
        )

        #expect(service.start() == .started)
        #expect(service.isRunning)
        #expect(service.start() == .alreadyRunning)

        service.stop()

        #expect(!service.isRunning)
    }
}

@MainActor
private final class PermissionRequestSpy {
    var wasCalled = false
}
