import Foundation
import Testing
@testable import FoundryCore

@Suite("Sleep session builder")
struct SleepBuilderTests {
    let keys = Fixture.keys
    /// Wake day 2026-09-24: window is 2026-09-23 18:00 → 2026-09-24 12:00 (New York).
    let wakeDay = "2026-09-24"

    private var window: DateInterval { SleepBuilder.window(forWakeDay: wakeDay, keys: keys)! }

    /// A sample by local clock time; hours ≥ 18 fall on the evening before the wake day.
    private func sample(_ source: String, _ stage: SleepStage,
                        _ startH: Int, _ startM: Int = 0, to endH: Int, _ endM: Int = 0) -> SleepSample {
        func at(_ h: Int, _ m: Int) -> Date {
            h >= 18 ? Fixture.date(2026, 9, 23, h, m) : Fixture.date(2026, 9, 24, h, m)
        }
        return SleepSample(sourceID: source, stage: stage, start: at(startH, startM), end: at(endH, endM))
    }

    // MARK: Window

    @Test func windowIsPreviousEvening6pmToNoon() {
        let w = window
        #expect(w.start == Fixture.date(2026, 9, 23, 18))
        #expect(w.end == Fixture.date(2026, 9, 24, 12))
        #expect(w.start == Fixture.instant("2026-09-23T22:00:00Z"))
        #expect(w.end == Fixture.instant("2026-09-24T16:00:00Z"))
        #expect(w.duration == 18 * 3600)
    }

    @Test func windowAcrossSpringForwardIs17Hours() {
        let w = SleepBuilder.window(forWakeDay: "2026-03-08", keys: keys)!
        #expect(w.start == Fixture.instant("2026-03-07T23:00:00Z")) // 18:00 EST
        #expect(w.end == Fixture.instant("2026-03-08T16:00:00Z"))   // 12:00 EDT
        #expect(w.duration == 17 * 3600)
    }

    @Test func windowAcrossFallBackIs19Hours() {
        let w = SleepBuilder.window(forWakeDay: "2026-11-01", keys: keys)!
        #expect(w.start == Fixture.instant("2026-10-31T22:00:00Z")) // 18:00 EDT
        #expect(w.end == Fixture.instant("2026-11-01T17:00:00Z"))   // 12:00 EST
        #expect(w.duration == 19 * 3600)
    }

    @Test func windowForMalformedKeyIsNil() {
        #expect(SleepBuilder.window(forWakeDay: "not-a-day", keys: keys) == nil)
    }

    // MARK: Build

    @Test func emptySamplesGiveEmptySummary() {
        #expect(SleepBuilder.build(samples: [], window: window) == SleepSummary())
    }

    @Test func stagesAreSummedPerStage() {
        let samples = [
            sample("watch", .core, 23, to: 1),       // 120
            sample("watch", .deep, 1, to: 2),        // 60
            sample("watch", .rem, 2, to: 3, 30),     // 90
            sample("watch", .awake, 3, 30, to: 3, 45), // 15
            sample("watch", .core, 3, 45, to: 6),    // 135
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(deep: 60, core: 255, rem: 90, awake: 15))
        #expect(s.asleep == 405)
    }

    @Test func overlappingSamplesFromSameSourceAreUnioned() {
        let samples = [
            sample("watch", .core, 23, to: 3),   // 23–03
            sample("watch", .core, 2, to: 5),    // overlaps 02–03
            sample("watch", .core, 23, to: 3),   // exact duplicate
            sample("watch", .core, 0, to: 1),    // fully contained
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s.core == 360) // 23–05, not 4+3+4+1 hours
        #expect(s.asleep == 360)
    }

    @Test func adjacentSamplesAreNotDoubleCounted() {
        let samples = [sample("watch", .deep, 1, to: 2), sample("watch", .deep, 2, to: 3)]
        #expect(SleepBuilder.build(samples: samples, window: window).deep == 120)
    }

    @Test func sourceWithMostAsleepWins() {
        let watch = [
            sample("watch", .core, 23, to: 3),  // 240
            sample("watch", .deep, 3, to: 4),   // 60
            sample("watch", .rem, 4, to: 6),    // 120
            sample("watch", .awake, 6, to: 6, 30),
        ]
        let phone = [
            sample("phone", .unspecified, 22, to: 5), // 420
            sample("phone", .unspecified, 5, to: 6),  // +60 → 480 asleep, beating the watch's 420
        ]
        let s = SleepBuilder.build(samples: watch + phone, window: window)
        #expect(s == SleepSummary(deep: 0, core: 480, rem: 0, awake: 0))

        // The winner is picked by asleep minutes, regardless of sample order.
        let reversed = SleepBuilder.build(samples: (phone + watch).reversed(), window: window)
        #expect(reversed == s)
    }

    @Test func sourcesAreNotMergedAcrossEachOther() {
        let samples = [
            sample("watch", .core, 23, to: 5),  // 360
            sample("ring", .core, 22, to: 4),   // 360, overlaps the watch
            sample("ring", .deep, 4, to: 5),    // +60 → 420 for ring
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(deep: 60, core: 360, rem: 0, awake: 0))
    }

    @Test func awakeDoesNotCountTowardChoosingTheSource() {
        let samples = [
            sample("a", .core, 23, to: 4),    // 300 asleep
            sample("b", .core, 23, to: 3),    // 240 asleep
            sample("b", .awake, 3, to: 9),    // lots of awake
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(core: 300))
    }

    @Test func tieBreaksToAlphabeticallyFirstSource() {
        let samples = [
            sample("zulu", .deep, 23, to: 1),
            sample("alpha", .core, 23, to: 1),
        ]
        #expect(SleepBuilder.build(samples: samples, window: window) == SleepSummary(core: 120))
        #expect(SleepBuilder.build(samples: samples.reversed(), window: window) == SleepSummary(core: 120))
    }

    @Test func unspecifiedAsleepCountsAsCore() {
        let samples = [sample("watch", .unspecified, 23, to: 6)]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(deep: 0, core: 420, rem: 0, awake: 0))
    }

    @Test func unspecifiedAndCoreOverlapAreUnioned() {
        let samples = [
            sample("watch", .unspecified, 23, to: 3),
            sample("watch", .core, 1, to: 5),
        ]
        #expect(SleepBuilder.build(samples: samples, window: window).core == 360)
    }

    @Test func inBedIsIgnored() {
        let samples = [
            sample("watch", .inBed, 21, to: 9),
            sample("watch", .core, 23, to: 6),
            sample("bed-sensor", .inBed, 18, to: 11, 59), // in-bed only source never wins
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(core: 420))
    }

    @Test func onlyInBedGivesEmptySummary() {
        let samples = [sample("watch", .inBed, 22, to: 7)]
        #expect(SleepBuilder.build(samples: samples, window: window).isEmpty)
    }

    @Test func samplesAreClippedToWindow() {
        let samples = [
            // Starts 16:00 the previous day; only 18:00–20:00 counts.
            SleepSample(sourceID: "watch", stage: .core,
                        start: Fixture.date(2026, 9, 23, 16), end: Fixture.date(2026, 9, 23, 20)),
            // Runs 11:00–14:00 on the wake day; only 11:00–12:00 counts.
            SleepSample(sourceID: "watch", stage: .deep,
                        start: Fixture.date(2026, 9, 24, 11), end: Fixture.date(2026, 9, 24, 14)),
        ]
        let s = SleepBuilder.build(samples: samples, window: window)
        #expect(s == SleepSummary(deep: 60, core: 120))
    }

    @Test func samplesEntirelyOutsideWindowAreDropped() {
        let samples = [
            SleepSample(sourceID: "watch", stage: .core,
                        start: Fixture.date(2026, 9, 23, 13), end: Fixture.date(2026, 9, 23, 17, 59)),
            SleepSample(sourceID: "watch", stage: .core,
                        start: Fixture.date(2026, 9, 24, 12), end: Fixture.date(2026, 9, 24, 15)),
        ]
        #expect(SleepBuilder.build(samples: samples, window: window).isEmpty)
    }

    @Test func clippingDecidesTheWinningSource() {
        let samples = [
            // 10 hours raw, but only 2 inside the window.
            SleepSample(sourceID: "nap", stage: .core,
                        start: Fixture.date(2026, 9, 24, 10), end: Fixture.date(2026, 9, 24, 20)),
            sample("watch", .core, 23, to: 2),  // 180 inside the window
        ]
        #expect(SleepBuilder.build(samples: samples, window: window) == SleepSummary(core: 180))
    }

    @Test func formatting() {
        #expect(SleepBuilder.formatDuration(minutes: 432) == "7h 12m")
        #expect(SleepBuilder.formatDuration(minutes: 60) == "1h 00m")
        #expect(SleepBuilder.formatClock(minutes: 80) == "1:20")
        #expect(SleepBuilder.formatClock(minutes: -5) == "0:00")
    }
}
