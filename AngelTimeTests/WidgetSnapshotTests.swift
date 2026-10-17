import XCTest
@testable import AngelTime

@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private func snapshot(_ f: Fixture) -> WidgetSnapshot {
        WidgetSnapshot(engine: f.engine, tasks: f.tasks, settings: f.settings)
    }

    func testIdleTimerSharesTimeLeftAndNoEndDate() {
        let f = Fixture()
        let s = snapshot(f)
        XCTAssertEqual(s.mode, .pomodoro)
        XCTAssertFalse(s.isRunning)
        XCTAssertFalse(s.hasStarted)
        XCTAssertNil(s.endDate)
        XCTAssertEqual(s.secondsLeft, 25 * 60)
        XCTAssertFalse(s.isCountingDown(at: f.clock.now))
        XCTAssertEqual(s.secondsLeft(at: f.clock.now.addingTimeInterval(600)), 25 * 60)
    }

    func testRunningTimerSharesEndDate() {
        let f = Fixture()
        f.engine.start()
        let s = snapshot(f)
        let end = f.clock.now.addingTimeInterval(25 * 60)
        XCTAssertEqual(s.endDate, end)
        XCTAssertNil(s.secondsLeft)
        XCTAssertTrue(s.isCountingDown(at: f.clock.now))
        XCTAssertEqual(s.secondsLeft(at: f.clock.now.addingTimeInterval(61)), 25 * 60 - 61)
        XCTAssertEqual(s.progress(at: f.clock.now.addingTimeInterval(5 * 60)), 0.2, accuracy: 0.001)
        XCTAssertFalse(s.isCountingDown(at: end))
        XCTAssertEqual(s.secondsLeft(at: end.addingTimeInterval(5)), 0)
    }

    func testTicksDoNotChangeARunningSnapshot() {
        let f = Fixture()
        f.engine.start()
        let before = snapshot(f)
        f.clock.advance(10)
        f.engine.tick()
        XCTAssertEqual(snapshot(f), before)
    }

    func testPausedTimerSharesTimeLeft() {
        let f = Fixture()
        f.engine.start()
        f.clock.advance(90)
        f.engine.pause()
        let s = snapshot(f)
        XCTAssertFalse(s.isRunning)
        XCTAssertTrue(s.hasStarted)
        XCTAssertNil(s.endDate)
        XCTAssertEqual(s.secondsLeft, 25 * 60 - 90)
    }

    func testCarriesActiveTaskAndThemeColors() {
        let f = Fixture()
        f.tasks.add(title: "Write report")
        f.settings.setColorID("plum", for: .shortBreak)
        let s = snapshot(f)
        XCTAssertEqual(s.taskTitle, "Write report")
        XCTAssertEqual(s.colorID(for: .shortBreak), "plum")
        XCTAssertEqual(s.colorID(for: .pomodoro), "tomato")
    }

    func testTodayCountResetsTheNextDay() {
        let f = Fixture()
        f.runCurrentSession()
        let s = snapshot(f)
        XCTAssertEqual(s.mode, .shortBreak)
        XCTAssertEqual(s.completedPomodoros(on: f.clock.now), 1)
        XCTAssertEqual(s.completedPomodoros(on: f.clock.now.addingTimeInterval(24 * 3600)), 0)
    }

    func testRoundTripsThroughJSON() throws {
        let f = Fixture()
        f.tasks.add(title: "Write report")
        f.clock.advance(0.4)
        f.engine.start()
        let s = snapshot(f)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }

    func testCommandsRoundTripThroughURLs() {
        for command in WidgetCommand.allCases {
            XCTAssertEqual(WidgetCommand(url: command.url), command)
        }
        XCTAssertNil(WidgetCommand(url: URL(string: "angeltime://reset")!))
        XCTAssertNil(WidgetCommand(url: URL(string: "https://toggle")!))
    }
}
