import SwiftUI

/// The small window: a compact timer and every task, both unfinished and completed.
struct TasksWindowView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(TaskStore.self) private var tasks
    @Environment(AppSettings.self) private var settings

    var onOpenSettings: () -> Void

    @State private var editingTaskID: UUID?
    @State private var isAddingTask = false
    @State private var confirmClearAll = false
    @AppStorage("tasksWindow.showCompleted") private var showCompleted = true

    var body: some View {
        let tint = settings.color(for: engine.mode)

        VStack(spacing: 0) {
            titleBar
            TimerCard(style: .window)
                .padding(.horizontal, 16)
            caption
                .padding(.top, 12)
                .padding(.bottom, 8)
            tasksHeader
                .padding(.horizontal, 16)
            taskList(tint: tint)
            footer
        }
        .frame(minWidth: 340, idealWidth: 380, minHeight: 500, idealHeight: 680)
        .background(tint)
        .ignoresSafeArea(.container, edges: .top)
        .animation(.easeInOut(duration: 0.4), value: engine.mode)
        .confirmationDialog("Delete all tasks?", isPresented: $confirmClearAll) {
            Button("Delete All Tasks", role: .destructive) { tasks.clearAll() }
        } message: {
            Text("This removes every task, finished or not. It can't be undone.")
        }
    }

    // MARK: Sections

    /// Sits in the transparent title bar, to the right of the window buttons.
    private var titleBar: some View {
        ZStack {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                Text("AngelTime")
            }
            .font(.system(size: 14, weight: .bold))

            HStack {
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(TranslucentButtonStyle())
                .help("Settings")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .padding(.bottom, 8)
    }

    private var caption: some View {
        VStack(spacing: 2) {
            Text("#\(engine.sessionNumber)")
                .font(.system(size: 13))
                .opacity(0.65)
                .monospacedDigit()
            Text(engine.mode == .pomodoro ? (tasks.activeTask?.title ?? engine.mode.message) : engine.mode.message)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 20)
        }
        .foregroundStyle(.white)
    }

    private var tasksHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Menu {
                    Button("Clear Finished Tasks", systemImage: "checkmark.circle") {
                        withAnimation { tasks.clearFinished() }
                    }
                    .disabled(tasks.completedTasks.isEmpty)
                    Button("Clear Act Pomodoros", systemImage: "arrow.counterclockwise") {
                        tasks.clearActPomodoros()
                    }
                    .disabled(tasks.totalCompletedPomodoros == 0)
                    Toggle("Show Completed Tasks", isOn: $showCompleted)
                    Divider()
                    Button("Clear All Tasks…", systemImage: "trash", role: .destructive) {
                        confirmClearAll = true
                    }
                    .disabled(tasks.tasks.isEmpty)
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(0.2)))
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Task options")
            }
            .foregroundStyle(.white)

            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(height: 2)
        }
    }

    private func taskList(tint: Color) -> some View {
        List {
            if tasks.tasks.isEmpty && !isAddingTask {
                emptyState
                    .taskListRow()
            }

            ForEach(tasks.pendingTasks) { task in
                row(for: task, tint: tint)
                    .taskListRow()
            }
            .onMove { source, destination in
                tasks.movePending(fromOffsets: source, toOffset: destination)
            }

            Group {
                if isAddingTask {
                    TaskEditor(
                        mode: .add,
                        onSave: { task in
                            withAnimation(.snappy) {
                                _ = tasks.add(title: task.title, estimate: task.estimatedPomodoros, note: task.note)
                            }
                            isAddingTask = false
                        },
                        onCancel: { isAddingTask = false }
                    )
                } else {
                    AddTaskButton {
                        editingTaskID = nil
                        isAddingTask = true
                    }
                }
            }
            .taskListRow()

            if !tasks.completedTasks.isEmpty {
                completedHeader
                    .taskListRow(top: 14)
                if showCompleted {
                    ForEach(tasks.completedTasks) { task in
                        row(for: task, tint: tint)
                            .taskListRow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // A legacy (always-visible) scroller would draw a white track over the colored background.
        .scrollIndicators(.never)
        .environment(\.defaultMinListRowHeight, 1)
        .animation(.snappy, value: tasks.tasks)
        .animation(.snappy, value: isAddingTask)
        .animation(.snappy, value: editingTaskID)
    }

    @ViewBuilder
    private func row(for task: PomoTask, tint: Color) -> some View {
        if editingTaskID == task.id {
            TaskEditor(
                mode: .edit(task),
                onSave: { edited in
                    tasks.update(edited)
                    editingTaskID = nil
                },
                onCancel: { editingTaskID = nil },
                onDelete: {
                    withAnimation(.snappy) { tasks.delete(id: task.id) }
                    editingTaskID = nil
                }
            )
        } else {
            TaskRow(
                task: task,
                isActive: task.id == tasks.activeTaskID,
                tint: tint,
                onToggle: { withAnimation(.snappy) { tasks.toggleDone(id: task.id) } },
                onSelect: { tasks.setActive(id: task.id) },
                onEdit: {
                    isAddingTask = false
                    editingTaskID = task.id
                },
                onDelete: { withAnimation(.snappy) { tasks.delete(id: task.id) } }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 26))
            Text("No tasks yet")
                .font(.system(size: 15, weight: .semibold))
            Text("Add what you're working on and estimate how many pomodoros it'll take.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var completedHeader: some View {
        Button {
            withAnimation(.snappy) { showCompleted.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(showCompleted ? 90 : 0))
                Text("Completed")
                Text("\(tasks.completedTasks.count)")
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.white.opacity(0.2)))
                Spacer()
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(showCompleted ? "Hide completed tasks" : "Show completed tasks")
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if !tasks.tasks.isEmpty {
                EstimateSummary()
                    .font(.system(size: 14, weight: .semibold))
            }
            Text("Today: \(engine.completedToday) pomodoro\(engine.completedToday == 1 ? "" : "s") · \(engine.focusSecondsToday.focusDurationText) focused")
                .font(.system(size: 12))
                .opacity(0.75)
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
        }
    }
}

/// Dashed "+ Add Task" button.
private struct AddTaskButton: View {
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add Task")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(hovering ? 0.12 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .keyboardShortcut("n", modifiers: .command)
        .help("Add a task (⌘N)")
    }
}

private extension View {
    /// Strips List chrome so rows float on the colored window background.
    func taskListRow(top: CGFloat = 5) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: 5, trailing: 16))
    }
}
