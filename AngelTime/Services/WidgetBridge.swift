import Foundation
import WidgetKit
import notify

/// Keeps the widget in step with the app. It publishes a `WidgetSnapshot` whenever something the
/// widget shows changes, and runs the widget's Start/Pause and Skip buttons on the TimerEngine,
/// which stays the single source of truth.
@MainActor
final class WidgetBridge {
    private let engine: TimerEngine
    private let tasks: TaskStore
    private let settings: AppSettings
    private var lastPublished: WidgetSnapshot?
    private var notifyTokens: [Int32] = []

    init(engine: TimerEngine, tasks: TaskStore, settings: AppSettings) {
        self.engine = engine
        self.tasks = tasks
        self.settings = settings

        for command in WidgetCommand.allCases {
            var token: Int32 = 0
            notify_register_dispatch(command.notificationName, &token, .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.perform(command) }
            }
            notifyTokens.append(token)
        }

        observeAndApply { [weak self] in self?.publishIfChanged() }
    }

    func perform(_ command: WidgetCommand) {
        switch command {
        case .toggle: engine.toggle()
        case .skip: engine.skip()
        }
    }

    /// Called as the app quits. The timer won't survive the quit, so show what the next launch
    /// will start with instead of a countdown that nothing is running.
    func publishQuit() {
        var snapshot = WidgetSnapshot(engine: engine, tasks: tasks, settings: settings)
        snapshot.mode = .pomodoro
        snapshot.isRunning = false
        snapshot.hasStarted = false
        snapshot.endDate = nil
        snapshot.sessionDuration = settings.duration(for: .pomodoro)
        snapshot.secondsLeft = Int(snapshot.sessionDuration)
        publish(snapshot)
    }

    private func publishIfChanged() {
        // Reads observable state, so this runs again on every change. Equal snapshots are
        // skipped, which keeps the once-a-second countdown from reloading the widget.
        let snapshot = WidgetSnapshot(engine: engine, tasks: tasks, settings: settings)
        guard snapshot != lastPublished else { return }
        publish(snapshot)
    }

    private func publish(_ snapshot: WidgetSnapshot) {
        do {
            try WidgetSnapshotStore.save(snapshot)
            lastPublished = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
        } catch {
            NSLog("AngelTime: could not save widget state: \(error)")
        }
    }
}

extension WidgetSnapshot {
    @MainActor
    init(engine: TimerEngine, tasks: TaskStore, settings: AppSettings) {
        let running = engine.isRunning
        self.init(
            mode: engine.mode,
            isRunning: running,
            hasStarted: engine.hasStarted,
            endDate: running ? engine.endDate : nil,
            // secondsLeft changes every second while running. Leave it out then, so it isn't
            // observed and doesn't count as a change.
            secondsLeft: running ? nil : engine.secondsLeft,
            sessionDuration: engine.sessionDuration,
            taskTitle: tasks.activeTask?.title,
            completedToday: engine.completedToday,
            statsDay: engine.statsDay,
            colorIDs: Dictionary(uniqueKeysWithValues: TimerMode.allCases.map {
                ($0.rawValue, settings.colorID(for: $0))
            })
        )
    }
}
