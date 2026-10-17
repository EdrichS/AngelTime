import SwiftUI

/// What opens from the menu bar icon: timer, the next few tasks, a quick-add field and shortcuts.
struct PopoverView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(TaskStore.self) private var tasks
    @Environment(AppSettings.self) private var settings

    var onOpenTasks: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    @State private var newTaskTitle = ""

    private let visibleTaskLimit = 5

    var body: some View {
        let tint = settings.color(for: engine.mode)

        VStack(spacing: 0) {
            TimerCard(style: .popover)
                .padding([.horizontal, .top], 10)

            caption
                .padding(.vertical, 10)

            Divider()

            taskSection(tint: tint)
                .padding(12)

            Divider()

            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(width: 340)
    }

    private var caption: some View {
        VStack(spacing: 2) {
            Text("#\(engine.sessionNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(engine.mode == .pomodoro ? (tasks.activeTask?.title ?? engine.mode.message) : engine.mode.message)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 16)
        }
    }

    private func taskSection(tint: Color) -> some View {
        let pending = tasks.pendingTasks

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tasks").font(.headline)
                if !tasks.tasks.isEmpty {
                    Text("\(tasks.completedTasks.count)/\(tasks.tasks.count) done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button(action: onOpenTasks) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Show all tasks")
            }
            .padding(.bottom, 2)

            if tasks.tasks.isEmpty {
                Text("No tasks yet. What are you working on?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else if pending.isEmpty {
                Text("You've finished all your tasks 🎉")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(pending.prefix(visibleTaskLimit)) { task in
                CompactTaskRow(
                    task: task,
                    isActive: task.id == tasks.activeTaskID,
                    tint: tint,
                    onToggle: { withAnimation(.snappy) { tasks.toggleDone(id: task.id) } },
                    onSelect: { tasks.setActive(id: task.id) }
                )
            }

            if pending.count > visibleTaskLimit {
                Button("+ \(pending.count - visibleTaskLimit) more…", action: onOpenTasks)
                    .buttonStyle(.link)
                    .font(.callout)
                    .padding(.leading, 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(tint)
                    .font(.system(size: 15))
                TextField("Add a task…", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .onSubmit(addTask)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.05)))
            .padding(.top, 6)

            if !tasks.tasks.isEmpty {
                EstimateSummary()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Button(action: onOpenTasks) {
                Label("All Tasks", systemImage: "checklist")
            }
            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            Spacer()
            Text("Today: \(engine.completedToday) 🍅 · \(engine.focusSecondsToday.focusDurationText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .help("Pomodoros finished and time focused today")
            Button(action: onQuit) {
                Image(systemName: "power")
            }
            .help("Quit AngelTime")
        }
        .buttonStyle(HoverButtonStyle())
        .font(.system(size: 12))
    }

    private func addTask() {
        if tasks.add(title: newTaskTitle) != nil {
            newTaskTitle = ""
        }
    }
}

private struct CompactTaskRow: View {
    let task: PomoTask
    let isActive: Bool
    let tint: Color
    var onToggle: () -> Void
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                CheckCircle(isDone: task.isDone, tint: tint, size: 17, outlined: true)
            }
            .buttonStyle(.plain)
            .help("Mark as done")

            Text(task.title)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 5)
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? tint.opacity(0.14) : .clear)
        )
        .overlay(alignment: .leading) {
            if isActive {
                Capsule().fill(tint).frame(width: 3).padding(.vertical, 5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help(isActive ? "You're working on this task" : "Click to work on this task")
    }
}
