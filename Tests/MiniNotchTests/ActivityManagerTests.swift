import Foundation
import Testing
@testable import MiniNotch

@MainActor
struct ActivityManagerTests {
    @Test
    func testPublishingNewActivityAddsSnapshotAndSelectsIt() {
        let manager = ActivityManager()

        manager.publish(TestActivity(id: "media", priority: 30, isActive: true))

        #expect(manager.activities.map(\.id) == ["media"])
        #expect(manager.currentActivityID == "media")
        #expect(manager.currentActivity?.priority == 30)
    }

    @Test
    func testPublishingExistingActivityUpdatesSnapshotInPlace() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "alert", priority: 20, isActive: true)
            ]
        )

        manager.publish(TestActivity(id: "alert", priority: 80, isActive: true))

        #expect(manager.activities.map(\.id) == ["media", "alert"])
        #expect(manager.activities.count == 2)
        #expect(manager.currentActivityID == "alert")
        #expect(manager.currentActivity?.priority == 80)
    }

    @Test
    func testPublishingSnapshotsActivatesAndDeactivatesExistingActivity() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "alert", priority: 80, isActive: false)
            ]
        )

        #expect(manager.currentActivityID == "media")

        manager.publish(TestActivity(id: "alert", priority: 80, isActive: true))

        #expect(manager.currentActivityID == "alert")

        manager.publish(TestActivity(id: "alert", priority: 80, isActive: false))

        #expect(manager.activities.map(\.id) == ["media", "alert"])
        #expect(manager.activeActivities.map(\.id) == ["media"])
        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testSelectsFirstActivePublishedActivity() {
        let manager = ActivityManager()

        manager.publish(TestActivity(id: "inactive", priority: 100, isActive: false))
        manager.publish(TestActivity(id: "media", priority: 30, isActive: true))

        #expect(manager.currentActivityID == "media")
        #expect(manager.currentActivity?.id == "media")
    }

    @Test
    func testPublishingEqualPriorityActivityPreservesCurrentSelection() {
        let manager = ActivityManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)]
        )

        manager.publish(TestActivity(id: "codex", priority: 30, isActive: true))

        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testRemovingCurrentActivityFallsBackToFirstPublishedEqualPriorityActivity() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "calendar", priority: 30, isActive: true),
                TestActivity(id: "codex", priority: 30, isActive: true)
            ],
            selectedActivityID: "codex"
        )

        manager.removeActivity(withID: "codex")

        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testHigherPriorityActivityReplacesLowerPriorityActivity() {
        let manager = ActivityManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)]
        )

        manager.publish(TestActivity(id: "volume", priority: 80, isActive: true))

        #expect(manager.currentActivityID == "volume")
    }

    @Test
    func testRemovingHigherPriorityActivityRestoresMatchingLowerPriorityActivity() {
        let manager = ActivityManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)]
        )

        manager.publish(TestActivity(id: "volume", priority: 80, isActive: true))
        manager.removeActivity(withID: "volume")

        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testMediaAndCodexCanBeSelectedManuallyAtEqualPriority() {
        let manager = ActivityManager(
            activities: [NotchContent.media, NotchContent.codexUsage],
            selectedActivityID: NotchContent.media.id
        )

        #expect(NotchContent.media.priority == NotchContent.codexUsage.priority)
        #expect(manager.selectActivity(withID: NotchContent.codexUsage.id))
        #expect(manager.currentActivityID == NotchContent.codexUsage.id)
        #expect(manager.selectActivity(withID: NotchContent.media.id))
        #expect(manager.currentActivityID == NotchContent.media.id)
    }

    @Test
    func testReplacingCurrentActivityWithInactiveSnapshotFallsBackToHighestActivePriority() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "codex", priority: 50, isActive: true)
            ]
        )

        manager.publish(TestActivity(id: "codex", priority: 50, isActive: false))

        #expect(manager.activities.map(\.id) == ["media", "codex"])
        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testReplacingCurrentActivityWithLowerPrioritySnapshotSelectsHigherActivity() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "codex", priority: 50, isActive: true)
            ],
            selectedActivityID: "codex"
        )

        manager.publish(TestActivity(id: "codex", priority: 20, isActive: true))

        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testRejectsManualSelectionBelowHighestActivePriority() {
        let manager = ActivityManager(
            activities: [
                TestActivity(id: "media", priority: 30, isActive: true),
                TestActivity(id: "volume", priority: 80, isActive: true),
                TestActivity(id: "inactive", priority: 100, isActive: false)
            ]
        )

        #expect(!manager.selectActivity(withID: "media"))
        #expect(!manager.selectActivity(withID: "inactive"))
        #expect(!manager.selectActivity(withID: "unknown"))
        #expect(manager.currentActivityID == "volume")
    }

    @Test
    func testPermanentMediaAndCodexActivitiesAreNotAutomaticallyRemoved() async {
        let sleeper = ControlledSleeper()
        let manager = ActivityManager(
            activities: [NotchContent.media, NotchContent.codexUsage],
            sleep: { duration in
                await sleeper.sleep(for: duration)
            }
        )

        await Task.yield()

        #expect(NotchContent.media.autoDismissAfter == nil)
        #expect(NotchContent.codexUsage.autoDismissAfter == nil)
        #expect(manager.activities.map(\.id) == [
            NotchContent.media.id,
            NotchContent.codexUsage.id
        ])
        #expect(sleeper.requestedDurations.isEmpty)
    }

    @Test
    func testMediaAndCodexRemainManuallySelectableAfterTemporaryDismiss() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [NotchContent.media, NotchContent.codexUsage],
            sleeper: sleeper
        )

        #expect(manager.selectActivity(withID: NotchContent.codexUsage.id))
        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )
        await sleeper.waitForRequestCount(1)

        sleeper.resumeRequest(at: 0)
        await waitUntil { manager.currentActivityID == NotchContent.media.id }

        #expect(manager.selectActivity(withID: NotchContent.codexUsage.id))
        #expect(manager.currentActivityID == NotchContent.codexUsage.id)
        #expect(manager.selectActivity(withID: NotchContent.media.id))
        #expect(manager.currentActivityID == NotchContent.media.id)
    }

    @Test
    func testTemporaryActivityIsRemovedAfterItsLifetime() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(sleeper: sleeper)

        manager.publish(
            TestActivity(
                id: "temporary",
                priority: 80,
                isActive: true,
                autoDismissAfter: 1.5
            )
        )

        await sleeper.waitForRequestCount(1)
        #expect(manager.currentActivityID == "temporary")

        sleeper.resumeRequest(at: 0)
        await waitUntil { manager.currentActivityID == nil }

        #expect(manager.activities.isEmpty)
    }

    @Test
    func testDismissingHigherPriorityActivityRestoresLowerPriorityActivity() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)],
            sleeper: sleeper
        )

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )

        await sleeper.waitForRequestCount(1)
        #expect(manager.currentActivityID == "alert")

        sleeper.resumeRequest(at: 0)
        await waitUntil { manager.currentActivityID == "media" }

        #expect(manager.activities.map(\.id) == ["media"])
    }

    @Test
    func testManualRemovalBeforeDismissIsSafe() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)],
            sleeper: sleeper
        )

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )
        await sleeper.waitForRequestCount(1)

        manager.removeActivity(withID: "alert")
        sleeper.resumeRequest(at: 0)
        await Task.yield()

        #expect(manager.activities.map(\.id) == ["media"])
        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testAutoDismissAndExplicitRemovalUseSameLifecycleResult() async {
        let explicitSleeper = ControlledSleeper()
        let automaticSleeper = ControlledSleeper()
        let activities: [any NotchActivity] = [
            TestActivity(id: "media", priority: 30, isActive: true),
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        ]
        let explicitlyRemovedManager = makeManager(
            activities: activities,
            sleeper: explicitSleeper
        )
        let automaticallyDismissedManager = makeManager(
            activities: activities,
            sleeper: automaticSleeper
        )

        await explicitSleeper.waitForRequestCount(1)
        await automaticSleeper.waitForRequestCount(1)

        explicitlyRemovedManager.removeActivity(withID: "alert")
        explicitSleeper.resumeRequest(at: 0)
        automaticSleeper.resumeRequest(at: 0)
        await waitUntil {
            automaticallyDismissedManager.currentActivityID == "media"
        }

        #expect(
            explicitlyRemovedManager.activities.map(\.id) ==
                automaticallyDismissedManager.activities.map(\.id)
        )
        #expect(
            explicitlyRemovedManager.currentActivityID ==
                automaticallyDismissedManager.currentActivityID
        )
        #expect(automaticallyDismissedManager.currentActivityID == "media")
    }

    @Test
    func testRepublishingTemporaryActivityRestartsFullLifetime() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(sleeper: sleeper)

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )
        await sleeper.waitForRequestCount(1)

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 90,
                isActive: true,
                autoDismissAfter: 5
            )
        )
        await sleeper.waitForRequestCount(2)

        #expect(sleeper.requestedDurations == [2, 5])

        sleeper.resumeRequest(at: 0)
        await Task.yield()

        #expect(manager.currentActivity?.priority == 90)

        sleeper.resumeRequest(at: 0)
        await waitUntil { manager.currentActivityID == nil }

        #expect(manager.activities.isEmpty)
    }

    @Test
    func testOldDismissTaskCannotRemoveNewPermanentVersion() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(sleeper: sleeper)

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )
        await sleeper.waitForRequestCount(1)

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 90,
                isActive: true,
                autoDismissAfter: nil
            )
        )

        sleeper.resumeRequest(at: 0)
        await Task.yield()

        #expect(manager.currentActivityID == "alert")
        #expect(manager.currentActivity?.priority == 90)
        #expect(manager.activities.count == 1)
        #expect(sleeper.requestedDurations == [2])
    }

    @Test
    func testTemporaryActivityPassedToInitializerStartsLifetime() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [
                TestActivity(
                    id: "temporary",
                    priority: 80,
                    isActive: true,
                    autoDismissAfter: 3
                )
            ],
            sleeper: sleeper
        )

        await sleeper.waitForRequestCount(1)
        #expect(sleeper.requestedDurations == [3])

        sleeper.resumeRequest(at: 0)
        await waitUntil { manager.currentActivityID == nil }

        #expect(manager.activities.isEmpty)
    }

    @Test
    func testInactiveSnapshotCancelsDismissWithoutStartingAnotherTask() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)],
            sleeper: sleeper
        )

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 2
            )
        )
        await sleeper.waitForRequestCount(1)

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: false,
                autoDismissAfter: 5
            )
        )

        sleeper.resumeRequest(at: 0)
        await Task.yield()

        #expect(sleeper.requestedDurations == [2])
        #expect(manager.activities.map(\.id) == ["media", "alert"])
        #expect(manager.currentActivityID == "media")
    }

    @Test
    func testNonPositiveLifetimeRemovesActivityImmediately() async {
        let sleeper = ControlledSleeper()
        let manager = makeManager(
            activities: [TestActivity(id: "media", priority: 30, isActive: true)],
            sleeper: sleeper
        )

        manager.publish(
            TestActivity(
                id: "alert",
                priority: 80,
                isActive: true,
                autoDismissAfter: 0
            )
        )
        await Task.yield()

        #expect(manager.activities.map(\.id) == ["media"])
        #expect(manager.currentActivityID == "media")
        #expect(sleeper.requestedDurations.isEmpty)
    }

    private func makeManager(
        activities: [any NotchActivity] = [],
        sleeper: ControlledSleeper
    ) -> ActivityManager {
        ActivityManager(activities: activities) { duration in
            await sleeper.sleep(for: duration)
        }
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            guard !condition() else { return }
            await Task.yield()
        }
    }
}

private struct TestActivity: NotchActivity {
    let id: String
    let priority: Int
    let isActive: Bool
    let autoDismissAfter: TimeInterval?

    init(
        id: String,
        priority: Int,
        isActive: Bool,
        autoDismissAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.priority = priority
        self.isActive = isActive
        self.autoDismissAfter = autoDismissAfter
    }
}

@MainActor
private final class ControlledSleeper {
    private struct Request {
        let continuation: CheckedContinuation<Void, Never>
    }

    private(set) var requestedDurations: [TimeInterval] = []
    private var requests: [Request] = []

    func sleep(for duration: TimeInterval) async {
        requestedDurations.append(duration)

        await withCheckedContinuation { continuation in
            requests.append(Request(continuation: continuation))
        }
    }

    func waitForRequestCount(_ count: Int) async {
        for _ in 0..<1_000 {
            guard requestedDurations.count < count else { return }
            await Task.yield()
        }
    }

    func resumeRequest(at index: Int) {
        requests.remove(at: index).continuation.resume()
    }
}
