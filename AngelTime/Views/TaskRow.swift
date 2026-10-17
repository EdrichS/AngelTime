import SwiftUI

/// A white task card in the Tasks window, styled like pomofocus.
struct TaskRow: View {
    let task: PomoTask
    let isActive: Bool
    let tint: Color
    var onToggle: () -> Void
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onToggle) {
                CheckCircle(isDone: task.isDone, tint: tint, size: 24)
            }
            .buttonStyle(.plain)
            .help(task.isDone ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(task.isDone ? Ink.faint : Ink.primary)
                    .strikethrough(task.isDone, color: Ink.faint)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.primary)
                        .lineLimit(4)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Ink.noteBackground))
                }
            }

            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Ink.faint)
                .monospacedDigit()
                .help("Pomodoros done / estimated")

            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Ink.secondary)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(white: 0.87)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit task")
        }
        .padding(.vertical, 14)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
        .overlay(alignment: .leading) {
            if isActive || (hovering && !task.isDone) {
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, style: .continuous)
                    .fill(isActive ? Color(white: 0.13) : Color(white: 0.8))
                    .frame(width: 6)
            }
        }
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.08), radius: hovering ? 4 : 2, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if !task.isDone { onSelect() }
        }
        .onHover { hovering = $0 }
        .contextMenu {
            if !task.isDone && !isActive {
                Button("Work on This Task", systemImage: "scope", action: onSelect)
            }
            Button(task.isDone ? "Mark as Not Done" : "Mark as Done",
                   systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark.circle",
                   action: onToggle)
            Button("Edit…", systemImage: "pencil", action: onEdit)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
