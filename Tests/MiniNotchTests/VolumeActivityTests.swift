import Testing
@testable import MiniNotch

@MainActor
struct VolumeActivityTests {
    @Test
    func testNormalizesVolumeAndPercentageToSupportedRange() {
        #expect(VolumeActivity(normalizedVolume: -0.2).normalizedVolume == 0)
        #expect(VolumeActivity(normalizedVolume: -0.2).percentage == 0)
        #expect(VolumeActivity(normalizedVolume: 0.724).percentage == 72)
        #expect(VolumeActivity(normalizedVolume: 1.2).normalizedVolume == 1)
        #expect(VolumeActivity(normalizedVolume: 1.2).percentage == 100)
    }

    @Test
    func testFormatsAllPercentageWidthsAsSingleLineText() {
        let cases: [(Double, String)] = [
            (0, "0 %"),
            (0.07, "7 %"),
            (0.42, "42 %"),
            (1, "100 %")
        ]

        for (volume, expectedText) in cases {
            let text = VolumeActivity(normalizedVolume: volume).percentageText
            #expect(text == expectedText)
            #expect(!text.contains("\n"))
        }
    }

    @Test
    func testExplicitMuteUsesMutePresentation() {
        let activity = VolumeActivity(normalizedVolume: 0.42, isMuted: true)

        #expect(activity.isMuted)
        #expect(activity.displayText == "Stumm")
    }

    @Test
    func testUnmutedVolumeUsesPercentagePresentation() {
        let activity = VolumeActivity(normalizedVolume: 0.42, isMuted: false)

        #expect(!activity.isMuted)
        #expect(activity.displayText == "42 %")
    }

    @Test
    func testUnmutedZeroVolumeRemainsPercentagePresentation() {
        let activity = VolumeActivity(normalizedVolume: 0, isMuted: false)

        #expect(!activity.isMuted)
        #expect(activity.displayText == "0 %")
    }

    @Test
    func testUsesStableIdentityPriorityAndAutoDismissDuration() {
        let first = VolumeActivity(normalizedVolume: 0.25)
        let updated = VolumeActivity(normalizedVolume: 0.75, isMuted: true)

        #expect(first.id == updated.id)
        #expect(first.id == VolumeActivity.activityID)
        #expect(first.priority == ActivityPriority.systemHUD)
        #expect(updated.priority == first.priority)
        #expect(first.priority > NotchContent.media.priority)
        #expect(first.priority > NotchContent.codexUsage.priority)
        #expect(first.autoDismissAfter == 1.5)
        #expect(updated.autoDismissAfter == first.autoDismissAfter)
        #expect(first.isActive)
    }

    @Test
    func testRepublishingUpdatesSameActivitySnapshot() {
        let manager = ActivityManager(activities: [NotchContent.media])

        manager.publish(VolumeActivity(normalizedVolume: 0.25))
        manager.publish(VolumeActivity(normalizedVolume: 0.75))

        let volumeActivities = manager.activities.compactMap { $0 as? VolumeActivity }
        #expect(volumeActivities.count == 1)
        #expect(volumeActivities.first?.normalizedVolume == 0.75)
        #expect(manager.currentActivityID == VolumeActivity.activityID)
    }

    @Test
    func testRepublishingMuteUpdatesExistingVolumeActivity() {
        let manager = ActivityManager(activities: [NotchContent.media])
        manager.publish(VolumeActivity(normalizedVolume: 0.42))
        let visibleActivityID = manager.currentActivityID

        manager.publish(VolumeActivity(normalizedVolume: 0.42, isMuted: true))

        let volumeActivities = manager.activities.compactMap { $0 as? VolumeActivity }
        #expect(volumeActivities.count == 1)
        #expect(volumeActivities.first?.isMuted == true)
        #expect(manager.currentActivityID == visibleActivityID)
        #expect(manager.currentActivityID == VolumeActivity.activityID)
    }

    @Test
    func testSilentVolumeUpdateDoesNotPublishActivity() {
        let model = AppModel()

        model.updateSystemVolume(0.72, presentsActivity: false)

        #expect(!model.activityManager.activities.contains {
            $0.id == VolumeActivity.activityID
        })
    }

    @Test
    func testVolumeActivityKeepsPresentationCollapsedDuringHover() {
        let model = AppModel()
        model.activityManager.publish(NotchContent.media)
        model.isHovered = true
        model.updateSystemVolume(0.72, presentsActivity: true)

        #expect(model.activityManager.currentActivityID == VolumeActivity.activityID)
        #expect(model.presentation == .collapsed)

        model.activityManager.removeActivity(withID: VolumeActivity.activityID)

        #expect(model.presentation == .expanded)
    }
}
