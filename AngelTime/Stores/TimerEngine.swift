import Foundation
import Observation

/// The Pomodoro state machine: focus → short break → focus → … → long break.
///
/// Time is measured against the wall clock (`endDate - now`), not by counting ticks, so the
/// timer stays accurate through sleep/wake, busy run loops and open menus.
@Observable
@MainActor
final class TimerEngine {
    struct SessionEvent: Equatable {
        let finished: TimerMode
        let next: TimerMode
        let nextStartedAutomatically: Bool
        /// True when the user pressed Skip. No alarm or notification is sent for skipped sessions.
        let skipped: Bool
    }

    struct FinishEstimate: Equatable {
        let remainingPomodoros: Int
        let duration: TimeInterval
        let finishDate: Date
    }

    private(set) var mode: TimerMode = .pomodoro
    private(set) var isRunning = false
    /// True once the current session has been started, until it ends or is reset.
    private(set) var hasStarted = false
    /// Whole seconds left in the current session. This is what the UI shows.
    private(set) var secondsLeft: Int
    private(set) var sessionDuration: TimeInterval
    /// Focus sessions finished today. Drives "#N" and the long-break cycle.
    private(set) var completedToday: Int
    private(set) var focusSecondsToday: TimeInterval

    /// Called whenever a session ends, whether it ran out or was skipped.
    @ObservationIgnored var onSessionEnd: ((SessionEvent) -> Void)?
    /// Called once per session when the "N minutes left" reminder is due.
    @ObservationIgnored var onReminder: ((TimerMode, Int) -> Void)?

    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored let tasks: TaskStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let usesTicker: Bool
    @ObservationIgnored private var remaining: TimeInterval
    /// When the running session ends. Nil while paused or idle.
    @ObservationIgnored private(set) var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var reminderSent = false
    /// The day that `completedToday` and `focusSecondsToday` count.
    @ObservationIgnored private(set) var statsDay: Date

    private enum Key {
        static let statsDay = "stats.day"
        static let completedToday = "stats.completedToday"
        static let focusSecondsToday = "stats.focusSecondsToday"
    }

    init(
        settings: AppSettings,
        tasks: TaskStore,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { Date() },
        usesTicker: Bool = true
    ) {
        self.settings = settings
        self.tasks = tasks
        self.defaults = defaults
        self.now = now
        self.usesTicker = usesTicker

        let duration = settings.duration(for: .pomodoro)
        sessionDuration = duration
        remaining = duration
        secondsLeft = Int(duration)

        let today = Calendar.current.startOfDay(for: now())
        let savedDay = Date(timeIntervalSince1970: defaults.double(forKey: Key.statsDay))
        if Calendar.current.isDate(savedDay, inSameDayAs: today) {
            completedToday = defaults.integer(forKey: Key.completedToday)
            focusSecondsToday = defaults.double(forKey: Key.focusSecondsToday)
        } else {
            completedToday = 0
            focusSecondsToday = 0
        }
        statsDay = today

        observe({ [weak self] in
            guard let self else { return }
            _ = self.settings.pomodoroMinutes
            _ = self.settings.shortBreakMinutes
            _ = self.settings.longBreakMinutes
        }, onChange: { [weak self] in
            self?.applyDurationSettings()
        })
    }

    // MARK: Display

    var timeString: String { Self.format(seconds: secondsLeft) }

    /// 0 at the start of a session, 1 at the end.
    var progress: Double {
        guard sessionDuration > 0 else { return 0 }
        return min(max(1 - Double(secondsLeft) / sessionDuration, 0), 1)
    }

    /// Round number shown as "#N" under the timer.
    var sessionNumber: Int { completedToday + 1 }

    static func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Controls

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        rollOverDayIfNeeded()
        if remaining <= 0 { remaining = sessionDuration }
        endDate = now().addingTimeInterval(remaining)
        isRunning = true
        hasStarted = true
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        syncRemaining()
        endDate = nil
        isRunning = false
        stopTicker()
    }

    /// Stops the timer and puts the current session back to its full length.
    func reset() {
        stopTicker()
        isRunning = false
        hasStarted = false
        endDate = nil
        reminderSent = false
        sessionDuration = settings.duration(for: mode)
        remaining = sessionDuration
        updateSecondsLeft()
    }

    func switchTo(_ newMode: TimerMode, autoStart: Bool = false) {
        mode = newMode
        reset()
        if autoStart { start() }
    }

    /// Ends the current session now and moves on, like pomofocus's skip button.
    func skip() {
        guard hasStarted else { return }
        finishSession(skipped: true)
    }

    /// Re-reads the clock. Called by the ticker, and after the Mac wakes.
    func tick() {
        guard isRunning else { return }
        syncRemaining()

        let reminder = settings.reminderMinutes
        if !reminderSent, reminder > 0, sessionDuration > TimeInterval(reminder * 60),
           remaining > 0, remaining <= TimeInterval(reminder * 60) {
            reminderSent = true
            onReminder?(mode, reminder)
        }

        if remaining <= 0 {
            finishSession(skipped: false)
        }
    }

    /// Resets "today" counters after midnight. Safe to call at any time.
    func rollOverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: now())
        guard today != statsDay else { return }
        statsDay = today
        completedToday = 0
        focusSecondsToday = 0
        saveStats()
    }

    // MARK: Estimates

    /// When all unfinished tasks will be done if the user keeps going, breaks included.
    func finishEstimate() -> FinishEstimate? {
        let pomodoros = tasks.remainingPomodoros
        guard pomodoros > 0 else { return nil }

        let focus = settings.duration(for: .pomodoro)
        let interval = max(1, settings.longBreakInterval)
        var total = TimeInterval(secondsLeft)
        var completed = completedToday
        var left = pomodoros
        var lastWasFocus = false

        if mode == .pomodoro {
            left -= 1
            completed += 1
            lastWasFocus = true
        }
        while left > 0 {
            if lastWasFocus {
                total += settings.duration(for: completed % interval == 0 ? .longBreak : .shortBreak)
            }
            total += focus
            left -= 1
            completed += 1
            lastWasFocus = true
        }
        return FinishEstimate(
            remainingPomodoros: pomodoros,
            duration: total,
            finishDate: now().addingTimeInterval(total)
        )
    }

    // MARK: Internals

    /// Picks up new session lengths from Settings. A session that has already started keeps its
    /// length, and the new one is used from the next session on.
    func applyDurationSettings() {
        let duration = settings.duration(for: mode)
        guard !hasStarted, duration != sessionDuration else { return }
        sessionDuration = duration
        remaining = duration
        updateSecondsLeft()
    }

    private func finishSession(skipped: Bool) {
        syncRemaining()
        let finished = mode
        let elapsed = max(0, sessionDuration - remaining)
        stopTicker()
        isRunning = false
        endDate = nil
        rollOverDayIfNeeded()

        let next: TimerMode
        if finished == .pomodoro {
            completedToday += 1
            focusSecondsToday += elapsed
            saveStats()
            tasks.recordPomodoro()
            next = completedToday % max(1, settings.longBreakInterval) == 0 ? .longBreak : .shortBreak
        } else {
            next = .pomodoro
        }

        let autoStart = next == .pomodoro ? settings.autoStartPomodoros : settings.autoStartBreaks
        switchTo(next, autoStart: autoStart)
        onSessionEnd?(SessionEvent(
            finished: finished,
            next: next,
            nextStartedAutomatically: autoStart,
            skipped: skipped
        ))
    }

    private func syncRemaining() {
        if let endDate {
            remaining = max(0, endDate.timeIntervalSince(now()))
        }
        updateSecondsLeft()
    }

    private func updateSecondsLeft() {
        let seconds = Int(remaining.rounded(.up))
        if seconds != secondsLeft { secondsLeft = seconds }
    }

    private func startTicker() {
        guard usesTicker, ticker == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        // .common keeps the timer firing while menus are open or windows are being resized.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func saveStats() {
        defaults.set(statsDay.timeIntervalSince1970, forKey: Key.statsDay)
        defaults.set(completedToday, forKey: Key.completedToday)
        defaults.set(focusSecondsToday, forKey: Key.focusSecondsToday)
    }
}
