import Foundation

public enum SleepStage: String, Sendable, CaseIterable, Codable {
    case deep, core, rem, awake
    /// "Asleep" with no stage detail. Counted as core.
    case unspecified
    /// Time in bed, not asleep. Ignored.
    case inBed
}

/// A raw sleep sample, independent of HealthKit.
public struct SleepSample: Sendable, Equatable {
    public var sourceID: String
    public var stage: SleepStage
    public var start: Date
    public var end: Date

    public init(sourceID: String, stage: SleepStage, start: Date, end: Date) {
        self.sourceID = sourceID
        self.stage = stage
        self.start = start
        self.end = end
    }
}

public enum SleepBuilder {
    /// The window credited to a wake day: previous day 6:00 PM to the wake day 12:00 PM.
    public static func window(forWakeDay dayKey: String, keys: DayKeys = DayKeys()) -> DateInterval? {
        guard let day = keys.date(for: dayKey),
              let end = keys.calendar.date(bySettingHour: GameRules.sleepWindowEndHour, minute: 0, second: 0, of: day),
              let previous = keys.calendar.date(byAdding: .day, value: -1, to: day),
              let start = keys.calendar.date(bySettingHour: GameRules.sleepWindowStartHour, minute: 0, second: 0, of: previous)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Builds one night's summary.
    ///
    /// Samples are clipped to the window and grouped by source. The source with the most
    /// asleep time wins, and its intervals are unioned per stage so overlaps never double count.
    public static func build(samples: [SleepSample], window: DateInterval) -> SleepSummary {
        var bySource: [String: [SleepSample]] = [:]
        for sample in samples where sample.stage != .inBed {
            guard let clipped = clip(sample, to: window) else { continue }
            bySource[clipped.sourceID, default: []].append(clipped)
        }
        let summaries = bySource.map { (source: $0.key, summary: summarize($0.value)) }
        let best = summaries.max { a, b in
            if a.summary.asleep != b.summary.asleep { return a.summary.asleep < b.summary.asleep }
            return a.source > b.source // stable tie-break: alphabetically first source wins
        }
        return best?.summary ?? SleepSummary()
    }

    static func clip(_ sample: SleepSample, to window: DateInterval) -> SleepSample? {
        let start = max(sample.start, window.start)
        let end = min(sample.end, window.end)
        guard end > start else { return nil }
        var s = sample
        s.start = start
        s.end = end
        return s
    }

    static func summarize(_ samples: [SleepSample]) -> SleepSummary {
        func minutes(_ stages: Set<SleepStage>) -> Int {
            let intervals = samples.filter { stages.contains($0.stage) }.map { ($0.start, $0.end) }
            return Int((unionLength(intervals) / 60).rounded())
        }
        return SleepSummary(
            deep: minutes([.deep]),
            core: minutes([.core, .unspecified]),
            rem: minutes([.rem]),
            awake: minutes([.awake])
        )
    }

    /// Total seconds covered by a set of possibly overlapping intervals.
    static func unionLength(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var current: (Date, Date)?
        for interval in sorted {
            if let c = current, interval.0 <= c.1 {
                current = (c.0, max(c.1, interval.1))
            } else {
                if let c = current { total += c.1.timeIntervalSince(c.0) }
                current = interval
            }
        }
        if let c = current { total += c.1.timeIntervalSince(c.0) }
        return total
    }

    /// `7h 12m` style duration.
    public static func formatDuration(minutes: Int) -> String {
        let m = max(0, minutes)
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }

    /// `1:20` style duration for stage legends.
    public static func formatClock(minutes: Int) -> String {
        let m = max(0, minutes)
        return "\(m / 60):\(String(format: "%02d", m % 60))"
    }
}
