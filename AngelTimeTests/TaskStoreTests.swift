import XCTest
@testable import AngelTime

@MainActor
final class TaskStoreTests: XCTestCase {
    func testFirstTaskBecomesActiveAndBlankTitlesAreIgnored() {
        let f = Fixture()
        XCTAssertNil(f.tasks.add(title: "   "))
        let first = f.tasks.add(title: "  Plan the week ")!
        f.tasks.add(title: "Email Sam")
        XCTAssertEqual(first.title, "Plan the week")
        XCTAssertEqual(f.tasks.activeTaskID, first.id)
    }

    func testCheckToBottomMovesFinishedTasksDown() {
        let f = Fixture()
        let a = f.tasks.add(title: "A")!
        let b = f.tasks.add(title: "B")!
        f.tasks.add(title: "C")

        f.tasks.setDone(true, id: a.id)
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["B", "C", "A"])
        XCTAssertEqual(f.tasks.activeTaskID, b.id, "Finishing the active task selects the next one")
        XCTAssertNotNil(f.tasks.task(id: a.id)?.completedAt)

        f.tasks.add(title: "D")
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["B", "C", "D", "A"], "New tasks go above finished ones")

        f.tasks.setDone(false, id: a.id)
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["B", "C", "D", "A"])
        XCTAssertNil(f.tasks.task(id: a.id)?.completedAt)
    }

    func testWithoutCheckToBottomTasksStayInPlace() {
        let f = Fixture()
        f.settings.checkToBottom = false
        let a = f.tasks.add(title: "A")!
        f.tasks.add(title: "B")
        f.tasks.setDone(true, id: a.id)
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["A", "B"])
        XCTAssertEqual(f.tasks.pendingTasks.map(\.title), ["B"])
        XCTAssertEqual(f.tasks.completedTasks.map(\.title), ["A"])
    }

    func testAutoCheckFinishesTaskWhenEstimateReached() {
        let f = Fixture()
        f.settings.autoCheckTasks = true
        let a = f.tasks.add(title: "A", estimate: 1)!
        let b = f.tasks.add(title: "B", estimate: 2)!

        f.runCurrentSession()

        XCTAssertEqual(f.tasks.task(id: a.id)?.isDone, true)
        XCTAssertEqual(f.tasks.activeTaskID, b.id)
    }

    func testWithoutAutoCheckTasksGoOverEstimate() {
        let f = Fixture()
        let a = f.tasks.add(title: "A", estimate: 1)!
        f.runCurrentSession()
        f.engine.switchTo(.pomodoro)
        f.runCurrentSession()
        XCTAssertEqual(f.tasks.task(id: a.id)?.completedPomodoros, 2)
        XCTAssertEqual(f.tasks.task(id: a.id)?.isDone, false)
    }

    func testMovePendingKeepsCompletedTasksInTheirSlots() {
        let f = Fixture()
        f.settings.checkToBottom = false
        let a = f.tasks.add(title: "A")!
        f.tasks.add(title: "B")
        f.tasks.add(title: "C")
        f.tasks.setDone(true, id: a.id)

        // Pending is [B, C]. Move C above B.
        f.tasks.movePending(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["A", "C", "B"])
    }

    func testDeletingActiveTaskSelectsNext() {
        let f = Fixture()
        let a = f.tasks.add(title: "A")!
        let b = f.tasks.add(title: "B")!
        f.tasks.delete(id: a.id)
        XCTAssertEqual(f.tasks.activeTaskID, b.id)
        f.tasks.delete(id: b.id)
        XCTAssertNil(f.tasks.activeTaskID)
    }

    func testFinishedTasksCannotBeActive() {
        let f = Fixture()
        let a = f.tasks.add(title: "A")!
        let b = f.tasks.add(title: "B")!
        f.tasks.setDone(true, id: b.id)
        f.tasks.setActive(id: b.id)
        XCTAssertEqual(f.tasks.activeTaskID, a.id)
    }

    func testClearActions() {
        let f = Fixture()
        let a = f.tasks.add(title: "A", estimate: 3)!
        f.tasks.add(title: "B")
        f.runCurrentSession()
        XCTAssertEqual(f.tasks.totalCompletedPomodoros, 1)

        f.tasks.clearActPomodoros()
        XCTAssertEqual(f.tasks.totalCompletedPomodoros, 0)

        f.tasks.setDone(true, id: a.id)
        f.tasks.clearFinished()
        XCTAssertEqual(f.tasks.tasks.map(\.title), ["B"])

        f.tasks.clearAll()
        XCTAssertTrue(f.tasks.tasks.isEmpty)
        XCTAssertNil(f.tasks.activeTaskID)
    }

    func testUpdateEditsFieldsAndClamps() {
        let f = Fixture()
        var task = f.tasks.add(title: "Draft")!
        task.title = "  "
        task.estimatedPomodoros = 500
        task.completedPomodoros = 4
        task.note = " remember the intro "
        f.tasks.update(task)

        let saved = f.tasks.task(id: task.id)!
        XCTAssertEqual(saved.title, "Draft", "A blank title keeps the old one")
        XCTAssertEqual(saved.estimatedPomodoros, 99)
        XCTAssertEqual(saved.completedPomodoros, 4)
        XCTAssertEqual(saved.note, "remember the intro")
    }

    func testTasksPersistToDisk() {
        let f = Fixture()
        let a = f.tasks.add(title: "A", estimate: 3, note: "note")!
        let b = f.tasks.add(title: "B")!
        f.tasks.setActive(id: b.id)
        f.tasks.setDone(true, id: a.id)

        let reloaded = TaskStore(settings: f.settings, fileURL: f.fileURL)
        // Dates are stored as ISO 8601 (whole seconds), so compare everything but timestamps.
        func summary(_ store: TaskStore) -> [String] {
            store.tasks.map { "\($0.id) \($0.title) \($0.note) \($0.estimatedPomodoros) \($0.completedPomodoros) \($0.isDone)" }
        }
        XCTAssertEqual(summary(reloaded), summary(f.tasks))
        XCTAssertEqual(reloaded.activeTaskID, b.id)
    }
}
