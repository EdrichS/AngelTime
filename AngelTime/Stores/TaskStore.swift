import Foundation
import Observation

/// Owns the task list and the active task, and saves both to disk on every change.
@Observable
@MainActor
final class TaskStore {
    /// Every task in display order. "To do" and "Completed" are filtered views of this array.
    private(set) var tasks: [PomoTask] = []
    private(set) var activeTaskID: UUID?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let fileURL: URL?

    private struct Snapshot: Codable {
        var tasks: [PomoTask]
        var activeTaskID: UUID?
    }

    init(settings: AppSettings, fileURL: URL? = TaskStore.defaultFileURL) {
        self.settings = settings
        self.fileURL = fileURL
        load()
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AngelTime", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }

    // MARK: Derived state

    var pendingTasks: [PomoTask] { tasks.filter { !$0.isDone } }
    var completedTasks: [PomoTask] { tasks.filter(\.isDone) }

    var activeTask: PomoTask? {
        guard let activeTaskID else { return nil }
        return tasks.first { $0.id == activeTaskID }
    }

    var totalCompletedPomodoros: Int { tasks.reduce(0) { $0 + $1.completedPomodoros } }
    var totalEstimatedPomodoros: Int { tasks.reduce(0) { $0 + $1.estimatedPomodoros } }

    /// Pomodoros still needed to finish every unfinished task.
    var remainingPomodoros: Int {
        pendingTasks.reduce(0) { $0 + max($1.estimatedPomodoros - $1.completedPomodoros, 0) }
    }

    func task(id: UUID) -> PomoTask? {
        tasks.first { $0.id == id }
    }

    // MARK: Editing

    @discardableResult
    func add(title: String, estimate: Int = 1, note: String = "") -> PomoTask? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let task = PomoTask(
            title: title,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedPomodoros: estimate.clamped(to: PomoTask.estimateRange)
        )
        // Keep finished tasks at the bottom by inserting new ones above them.
        if settings.checkToBottom, let firstDone = tasks.firstIndex(where: \.isDone) {
            tasks.insert(task, at: firstDone)
        } else {
            tasks.append(task)
        }
        if activeTask == nil || activeTask?.isDone == true {
            activeTaskID = task.id
        }
        save()
        return task
    }

    func update(_ edited: PomoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == edited.id }) else { return }
        var task = edited
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.title = title.isEmpty ? tasks[index].title : title
        task.note = task.note.trimmingCharacters(in: .whitespacesAndNewlines)
        task.estimatedPomodoros = task.estimatedPomodoros.clamped(to: PomoTask.estimateRange)
        task.completedPomodoros = max(0, task.completedPomodoros)
        let doneChanged = tasks[index].isDone != task.isDone
        tasks[index] = task
        if doneChanged {
            setDone(task.isDone, id: task.id)
        } else {
            save()
        }
    }

    func setDone(_ done: Bool, id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        var task = tasks.remove(at: index)
        task.isDone = done
        task.completedAt = done ? (task.completedAt ?? Date()) : nil

        if settings.checkToBottom {
            if done {
                tasks.append(task)
            } else {
                tasks.insert(task, at: tasks.firstIndex(where: \.isDone) ?? tasks.endIndex)
            }
        } else {
            tasks.insert(task, at: index)
        }

        if done, activeTaskID == id {
            activeTaskID = firstPendingID(from: index)
        } else if !done, activeTask == nil {
            activeTaskID = id
        }
        save()
    }

    func toggleDone(id: UUID) {
        guard let task = task(id: id) else { return }
        setDone(!task.isDone, id: id)
    }

    /// Makes a task the one that finished pomodoros are credited to. Finished tasks can't be active.
    func setActive(id: UUID) {
        guard let task = task(id: id), !task.isDone, activeTaskID != id else { return }
        activeTaskID = id
        save()
    }

    func delete(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
        if activeTaskID == id {
            activeTaskID = firstPendingID(from: index)
        }
        save()
    }

    /// Reorders the unfinished tasks. Offsets are positions in `pendingTasks`, and finished
    /// tasks keep their slots in the full list.
    func movePending(fromOffsets source: IndexSet, toOffset destination: Int) {
        var pending = pendingTasks
        pending.move(fromOffsets: source, toOffset: destination)
        var reordered = pending.makeIterator()
        tasks = tasks.map { $0.isDone ? $0 : reordered.next()! }
        save()
    }

    /// Credits one finished pomodoro to the active task.
    func recordPomodoro() {
        guard let id = activeTaskID, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].completedPomodoros += 1
        let task = tasks[index]
        if settings.autoCheckTasks, !task.isDone, task.completedPomodoros >= task.estimatedPomodoros {
            setDone(true, id: id)
        } else {
            save()
        }
    }

    func clearFinished() {
        tasks.removeAll(where: \.isDone)
        if activeTask == nil {
            activeTaskID = pendingTasks.first?.id
        }
        save()
    }

    func clearActPomodoros() {
        for index in tasks.indices {
            tasks[index].completedPomodoros = 0
        }
        save()
    }

    func clearAll() {
        tasks.removeAll()
        activeTaskID = nil
        save()
    }

    // MARK: Persistence

    private func firstPendingID(from index: Int) -> UUID? {
        let start = min(index, tasks.endIndex)
        return tasks[start...].first(where: { !$0.isDone })?.id ?? pendingTasks.first?.id
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            tasks = snapshot.tasks
            if let id = snapshot.activeTaskID, task(id: id)?.isDone == false {
                activeTaskID = id
            } else {
                activeTaskID = pendingTasks.first?.id
            }
        } catch {
            NSLog("AngelTime: could not read tasks file: \(error)")
        }
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(Snapshot(tasks: tasks, activeTaskID: activeTaskID))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("AngelTime: could not save tasks: \(error)")
        }
    }
}
