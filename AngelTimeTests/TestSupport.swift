import Foundation
@testable import AngelTime

/// A clock the tests move forward by hand.
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

/// Settings, task store and engine wired together against throwaway storage.
@MainActor
struct Fixture {
    let defaults: UserDefaults
    let settings: AppSettings
    let tasks: TaskStore
    let clock: TestClock
    let engine: TimerEngine
    let fileURL: URL

    init() {
        let suite = "AngelTimeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AngelTimeTests-\(UUID().uuidString)")
            .appendingPathComponent("tasks.json")
        settings = AppSettings(defaults: defaults)
        tasks = TaskStore(settings: settings, fileURL: fileURL)
        let clock = TestClock()
        self.clock = clock
        engine = TimerEngine(settings: settings, tasks: tasks, defaults: defaults, now: { clock.now }, usesTicker: false)
    }

    /// Starts the current session and runs it to the end.
    func runCurrentSession() {
        engine.start()
        clock.advance(TimeInterval(engine.secondsLeft))
        engine.tick()
    }
}

/// Lets main-actor tasks scheduled by observation callbacks run.
func drainMainQueue() {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}
