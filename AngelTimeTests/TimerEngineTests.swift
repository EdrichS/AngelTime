import XCTest
@testable import AngelTime

@MainActor
final class TimerEngineTests: XCTestCase {
    func testStartsIdleOnAFullPomodoro() {
        let f = Fixture()
        XCTAssertEqual(f.engine.mode, .pomodoro)
        XCTAssertFalse(f.engine.isRunning)
        XCTAssertFalse(f.engine.hasStarted)
        XCTAssertEqual(f.engine.secondsLeft, 25 * 60)
        XCTAssertEqual(f.engine.timeString, "25:00")
    }

    func testCountsDownAgainstTheClock() {
        let f = Fixture()
        f.engine.start()
        f.clock.advance(61)
        f.engine.tick()
        XCTAssertEqual(f.engine.secondsLeft, 25 * 60 - 61)
        XCTAssertEqual(f.engine.timeString, "23:59")
    }

    func testPauseFreezesTimeAndResumeContinues() {
        let f = Fixture()
        f.engine.start()
        f.clock.advance(100)
        f.engine.pause()
        f.clock.advance(500)
        f.engine.tick()
        XCTAssertEqual(f.engine.secondsLeft, 1400)
        XCTAssertTrue(f.engine.hasStarted)

        f.engine.start()
        f.clock.advance(10)
        f.engine.tick()
        XCTAssertEqual(f.engine.secondsLeft, 1390)
    }

    func testResetRestoresFullLength() {
        let f = Fixture()
        f.engine.start()
        f.clock.advance(300)
        f.engine.tick()
        f.engine.reset()
        XCTAssertFalse(f.engine.isRunning)
        XCTAssertFalse(f.engine.hasStarted)
        XCTAssertEqual(f.engine.secondsLeft, 1500)
    }

    func testFinishedPomodoroCreditsTaskAndMovesToShortBreak() {
        let f = Fixture()
        let task = f.tasks.add(title: "Write chapter", estimate: 2)!
        var events: [TimerEngine.SessionEvent] = []
        f.engine.onSessionEnd = { events.append($0) }

        f.runCurrentSession()

        XCTAssertEqual(f.engine.mode, .shortBreak)
        XCTAssertFalse(f.engine.isRunning, "Breaks don't auto start by default")
        XCTAssertEqual(f.engine.secondsLeft, 5 * 60)
        XCTAssertEqual(f.engine.completedToday, 1)
        XCTAssertEqual(f.engine.focusSecondsToday, 1500)
        XCTAssertEqual(f.tasks.task(id: task.id)?.completedPomodoros, 1)
        XCTAssertEqual(events, [.init(finished: .pomodoro, next: .shortBreak, nextStartedAutomatically: false, skipped: false)])
    }

    func testLongBreakComesAfterTheInterval() {
        let f = Fixture()
        f.settings.longBreakInterval = 2

        f.runCurrentSession() // focus 1
        XCTAssertEqual(f.engine.mode, .shortBreak)
        f.runCurrentSession() // short break
        XCTAssertEqual(f.engine.mode, .pomodoro)
        f.runCurrentSession() // focus 2
        XCTAssertEqual(f.engine.mode, .longBreak)
        XCTAssertEqual(f.engine.secondsLeft, 15 * 60)
        f.runCurrentSession() // long break
        XCTAssertEqual(f.engine.mode, .pomodoro)
        XCTAssertEqual(f.engine.sessionNumber, 3)
    }

    func testAutoStartSettings() {
        let f = Fixture()
        f.settings.autoStartBreaks = true
        f.runCurrentSession()
        XCTAssertEqual(f.engine.mode, .shortBreak)
        XCTAssertTrue(f.engine.isRunning)

        f.clock.advance(300)
        f.engine.tick()
        XCTAssertEqual(f.engine.mode, .pomodoro)
        XCTAssertFalse(f.engine.isRunning, "Pomodoros don't auto start unless enabled")
    }

    func testSkipFinishesEarlyWithoutAlarmFlag() {
        let f = Fixture()
        var events: [TimerEngine.SessionEvent] = []
        f.engine.onSessionEnd = { events.append($0) }

        f.engine.skip()
        XCTAssertTrue(events.isEmpty, "Skip does nothing before the session starts")

        f.engine.start()
        f.clock.advance(600)
        f.engine.skip()
        XCTAssertEqual(f.engine.mode, .shortBreak)
        XCTAssertEqual(f.engine.completedToday, 1)
        XCTAssertEqual(f.engine.focusSecondsToday, 600)
        XCTAssertEqual(events.last?.skipped, true)
    }

    func testChangingLengthWhileIdleAppliesImmediately() {
        let f = Fixture()
        f.settings.setMinutes(50, for: .pomodoro)
        drainMainQueue()
        XCTAssertEqual(f.engine.secondsLeft, 50 * 60)
        XCTAssertEqual(f.engine.timeString, "50:00")
    }

    func testChangingLengthMidSessionWaitsForNextSession() {
        let f = Fixture()
        f.engine.start()
        f.clock.advance(10)
        f.engine.tick()

        f.settings.setMinutes(50, for: .pomodoro)
        f.settings.setMinutes(7, for: .shortBreak)
        drainMainQueue()
        XCTAssertEqual(f.engine.secondsLeft, 1490, "The running session keeps its length")

        f.engine.skip()
        XCTAssertEqual(f.engine.secondsLeft, 7 * 60, "The next session uses the new length")
        f.engine.switchTo(.pomodoro)
        XCTAssertEqual(f.engine.secondsLeft, 50 * 60)
    }

    func testMinutesAreClampedToAllowedRange() {
        let f = Fixture()
        f.settings.setMinutes(500, for: .pomodoro)
        f.settings.setMinutes(0, for: .shortBreak)
        XCTAssertEqual(f.settings.pomodoroMinutes, 180)
        XCTAssertEqual(f.settings.shortBreakMinutes, 1)
    }

    func testSettingsPersist() {
        let f = Fixture()
        f.settings.setMinutes(40, for: .pomodoro)
        f.settings.setMinutes(8, for: .shortBreak)
        f.settings.setMinutes(22, for: .longBreak)
        f.settings.autoCheckTasks = true

        let reloaded = AppSettings(defaults: f.defaults)
        XCTAssertEqual(reloaded.pomodoroMinutes, 40)
        XCTAssertEqual(reloaded.shortBreakMinutes, 8)
        XCTAssertEqual(reloaded.longBreakMinutes, 22)
        XCTAssertTrue(reloaded.autoCheckTasks)
    }

    func testReminderFiresOnce() {
        let f = Fixture()
        f.settings.reminderMinutes = 1
        var reminders = 0
        f.engine.onReminder = { _, _ in reminders += 1 }

        f.engine.start()
        f.clock.advance(1500 - 61)
        f.engine.tick()
        XCTAssertEqual(reminders, 0)
        f.clock.advance(2)
        f.engine.tick()
        f.clock.advance(5)
        f.engine.tick()
        XCTAssertEqual(reminders, 1)
    }

    func testFinishEstimateIncludesBreaks() {
        let f = Fixture()
        f.tasks.add(title: "A", estimate: 2)
        f.tasks.add(title: "B", estimate: 1)

        let estimate = f.engine.finishEstimate()
        // 3 pomodoros with 2 short breaks between them: 25 + 5 + 25 + 5 + 25 = 85 min.
        XCTAssertEqual(estimate?.remainingPomodoros, 3)
        XCTAssertEqual(estimate?.duration, 85 * 60)
        XCTAssertEqual(estimate?.finishDate, f.clock.now.addingTimeInterval(85 * 60))
    }

    func testFinishEstimateUsesLongBreakAtInterval() {
        let f = Fixture()
        f.settings.longBreakInterval = 2
        f.tasks.add(title: "A", estimate: 3)
        // focus 25, short 5, focus 25, long 15 (2nd pomodoro hits the interval), focus 25 = 95 min.
        XCTAssertEqual(f.engine.finishEstimate()?.duration, 95 * 60)
    }

    func testNoEstimateWithoutTasks() {
        let f = Fixture()
        XCTAssertNil(f.engine.finishEstimate())
    }
}
