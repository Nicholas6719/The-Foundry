import Foundation
import FoundryCore
#if os(iOS)
import HealthKit
#endif

/// Reads sleep, workouts and resting heart rate (iPhone only) and writes `DailyVitals`.
@Observable
final class HealthService {
    enum Access: Equatable {
        /// This device or build has no Health (Mac, or HealthKit switched off).
        case unavailable
        /// Never asked.
        case notDetermined
        /// Asked. iOS never says whether reading was allowed, so "no data" may mean denied.
        case requested
    }

    private(set) var access: Access = .unavailable
    private(set) var isRefreshing = false
    private(set) var lastSync: Date?
    @ObservationIgnored private let store: FoundryStore
    @ObservationIgnored private var observing = false

    init(store: FoundryStore) {
        self.store = store
        lastSync = store.defaults.object(forKey: DefaultsKey.healthLastSync) as? Date
        #if os(iOS)
        if Capabilities.healthKit && HKHealthStore.isHealthDataAvailable() {
            access = store.defaults.bool(forKey: DefaultsKey.healthRequested) ? .requested : .notDetermined
        }
        #endif
    }

    var isAvailable: Bool { access != .unavailable }

    #if os(iOS)
    @ObservationIgnored private let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(), HKQuantityType(.restingHeartRate)]
    }

    /// Asks for read access, then syncs.
    func requestAccess() async {
        guard access != .unavailable else { return }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            Log.health.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        store.defaults.set(true, forKey: DefaultsKey.healthRequested)
        store.profile().healthEnabled = true
        store.save()
        access = .requested
        startObserving()
        await refresh()
    }

    /// Re-reads the last 14 days from Health.
    func refresh() async {
        guard access == .requested, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let keys = store.keys
        let today = keys.key(for: Date())
        let days = keys.trailing(14, endingOn: today)
        guard let first = days.first, let rangeStart = SleepBuilder.window(forWakeDay: first, keys: keys)?.start,
              let rangeEnd = keys.date(for: keys.adding(1, to: today)) else { return }
        do {
            async let sleep = sleepSamples(from: rangeStart, to: rangeEnd)
            async let workouts = workoutSamples(from: rangeStart, to: rangeEnd)
            async let heart = heartSamples(from: rangeStart, to: rangeEnd)
            let (s, w, h) = try await (sleep, workouts, heart)
            store.upsertVitals(Self.build(days: days, sleep: s, workouts: w, heart: h, keys: keys))
            lastSync = Date()
            store.defaults.set(lastSync, forKey: DefaultsKey.healthLastSync)
        } catch {
            Log.health.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Wakes the app when new samples land (background delivery when entitled).
    func startObserving() {
        guard access == .requested, !observing else { return }
        observing = true
        for type in readTypes.compactMap({ $0 as? HKSampleType }) {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                if let error {
                    Log.health.error("Observer error: \(error.localizedDescription, privacy: .public)")
                }
                completion()
                Task { @MainActor in await self?.refresh() }
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { ok, error in
                if !ok {
                    Log.health.info("Background delivery unavailable: \(error?.localizedDescription ?? "no entitlement", privacy: .public)")
                }
            }
        }
    }

    private func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: healthStore).compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
            let stage: SleepStage = switch value {
            case .asleepDeep: .deep
            case .asleepCore: .core
            case .asleepREM: .rem
            case .awake: .awake
            case .inBed: .inBed
            default: .unspecified
            }
            return SleepSample(sourceID: sample.sourceRevision.source.bundleIdentifier, stage: stage,
                               start: sample.startDate, end: sample.endDate)
        }
    }

    private func workoutSamples(from start: Date, to end: Date) async throws -> [(Date, TimeInterval)] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: healthStore).map { ($0.startDate, $0.duration) }
    }

    private func heartSamples(from start: Date, to end: Date) async throws -> [(Date, Int)] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await descriptor.result(for: healthStore).map {
            ($0.endDate, Int($0.quantity.doubleValue(for: unit).rounded()))
        }
    }
    #else
    func requestAccess() async {}
    func refresh() async {}
    func startObserving() {}
    #endif

    /// Folds raw samples into one value per day. Pure, so it is easy to reason about.
    static func build(days: [String], sleep: [SleepSample], workouts: [(Date, TimeInterval)],
                      heart: [(Date, Int)], keys: DayKeys) -> [VitalsValue] {
        let workoutsByDay = Dictionary(grouping: workouts) { keys.key(for: $0.0) }
        let heartByDay = Dictionary(grouping: heart) { keys.key(for: $0.0) }
        return days.map { day in
            let summary = SleepBuilder.window(forWakeDay: day, keys: keys)
                .map { SleepBuilder.build(samples: sleep, window: $0) } ?? SleepSummary()
            let dayWorkouts = workoutsByDay[day] ?? []
            // Resting HR: latest reading from this day, else the day before.
            let hr = (heartByDay[day] ?? heartByDay[keys.adding(-1, to: day)])?.max { $0.0 < $1.0 }?.1
            return VitalsValue(dayKey: day, sleep: summary, restingHR: hr,
                               workoutMinutes: Int((dayWorkouts.reduce(0) { $0 + $1.1 } / 60).rounded()),
                               workoutCount: dayWorkouts.count)
        }
    }
}
