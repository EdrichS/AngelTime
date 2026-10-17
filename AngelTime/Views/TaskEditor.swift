import SwiftUI

/// Inline editor card for adding or editing a task, modeled on pomofocus's.
struct TaskEditor: View {
    enum Mode {
        case add
        case edit(PomoTask)
    }

    let mode: Mode
    var onSave: (PomoTask) -> Void
    var onCancel: () -> Void
    var onDelete: (() -> Void)?

    @State private var title: String
    @State private var note: String
    @State private var estimate: Int
    @State private var actual: Int
    @State private var showsNote: Bool
    @FocusState private var titleFocused: Bool

    init(
        mode: Mode,
        onSave: @escaping (PomoTask) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        let task = if case .edit(let existing) = mode { existing } else { PomoTask(title: "") }
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note)
        _estimate = State(initialValue: task.estimatedPomodoros)
        _actual = State(initialValue: task.completedPomodoros)
        _showsNote = State(initialValue: !task.note.isEmpty)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("What are you working on?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Ink.primary)
                    .focused($titleFocused)
                    .onSubmit(save)

                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditing ? "Act / Est Pomodoros" : "Est Pomodoros")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Ink.primary)
                    HStack(spacing: 10) {
                        if isEditing {
                            NumberBox(value: $actual, range: 0...999)
                            Text("/").font(.system(size: 18, weight: .bold)).foregroundStyle(Ink.faint)
                        }
                        NumberBox(value: $estimate, range: PomoTask.estimateRange)
                    }
                }

                if showsNote {
                    TextField("Some notes…", text: $note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...6)
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.primary)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Ink.field))
                } else {
                    Button("+ Add Note") { showsNote = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Ink.secondary)
                        .underline()
                }
            }
            .padding(20)

            HStack(spacing: 14) {
                if let onDelete {
                    Button("Delete", action: onDelete)
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Ink.secondary)
                Button("Save", action: save)
                    .buttonStyle(DarkPillButtonStyle())
                    .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(white: 0.94))
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .environment(\.colorScheme, .light)
        .onExitCommand(perform: onCancel)
        .onAppear { titleFocused = true }
    }

    private func save() {
        guard canSave else { return }
        var task = if case .edit(let existing) = mode { existing } else { PomoTask(title: "") }
        task.title = title
        task.note = showsNote ? note : ""
        task.estimatedPomodoros = estimate
        if isEditing { task.completedPomodoros = actual }
        onSave(task)
    }
}
