import Foundation
import Testing
@testable import MiniNotch

struct MediaStateTests {
    @Test
    func testTimelineAdvancesDuringPlayback() {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = MediaState(
            isPlaying: true,
            duration: 240,
            elapsedTime: 80,
            receivedAt: receivedAt
        )
        let date = receivedAt.addingTimeInterval(10)

        #expect(state.currentElapsedTime(at: date) == 90)
        #expect(state.displayedElapsedTime(at: date) == 89)
        #expect(state.progress(at: date) == 89.0 / 240.0)
        #expect(state.elapsedTimeText(at: date) == "1:29")
        #expect(state.durationText == "4:00")
    }

    @Test
    func testPausedTimelineDoesNotAdvance() {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = MediaState(
            isPlaying: false,
            duration: 219,
            elapsedTime: 200,
            receivedAt: receivedAt
        )

        #expect(
            state.elapsedTimeText(at: receivedAt.addingTimeInterval(30)) == "3:19"
        )
        #expect(state.durationText == "3:39")
    }

    @Test
    func testTimelineClampsElapsedTimeToDuration() {
        let receivedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = MediaState(
            isPlaying: true,
            duration: 30,
            elapsedTime: 29,
            receivedAt: receivedAt
        )

        #expect(state.currentElapsedTime(at: receivedAt.addingTimeInterval(10)) == 30)
        #expect(state.displayedElapsedTime(at: receivedAt.addingTimeInterval(10)) == 30)
        #expect(state.progress(at: receivedAt.addingTimeInterval(10)) == 1)
        #expect(state.elapsedTimeText(at: receivedAt.addingTimeInterval(10)) == "0:30")
    }

    @Test
    func testTimelineDisplayDelayDoesNotProduceNegativeTime() {
        let state = MediaState(duration: 60, elapsedTime: 0.4)

        #expect(state.displayedElapsedTime() == 0)
        #expect(state.elapsedTimeText() == "0:00")
        #expect(state.progress() == 0)
    }

    @Test
    func testTimelineHandlesLongAndUnavailableDurations() {
        #expect(MediaState.playbackTimeText(3_723) == "1:02:03")

        let state = MediaState(duration: 0, elapsedTime: 12)
        #expect(!state.hasTimeline)
        #expect(state.progress() == 0)
        #expect(state.elapsedTimeText() == "--:--")
        #expect(state.durationText == "--:--")
        #expect(state.timelineAccessibilityText() == "Zeitangaben nicht verfügbar")
    }
}
