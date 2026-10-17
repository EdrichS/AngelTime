import SwiftUI

/// Text color used on the white task cards, which stay light in Dark Mode like pomofocus.
enum Ink {
    static let primary = Color(white: 0.33)
    static let secondary = Color(white: 0.53)
    static let faint = Color(white: 0.67)
    static let field = Color(white: 0.94)
    static let noteBackground = Color(red: 0.99, green: 0.97, blue: 0.87)
}

/// pomofocus's chunky START button: a white face on a light gray lip. The face drops onto the
/// lip while it's pressed, and stays down while the timer runs.
struct ChunkyButtonStyle: ButtonStyle {
    var tint: Color
    var engaged: Bool
    var width: CGFloat = 170
    var height: CGFloat = 50

    private let lip: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let down = engaged || configuration.isPressed
        return configuration.label
            .font(.system(size: 21, weight: .bold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
            .offset(y: down ? lip : 0)
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.88))
                    .frame(height: height)
                    .offset(y: lip)
                    .opacity(down ? 0 : 1)
            }
            .frame(height: height + lip, alignment: .top)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: down)
    }
}

/// Small round white-on-color button used for Reset and Skip next to the START button.
struct RoundIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(0.2)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Pomodoro / Short Break / Long Break selector.
struct ModeTabs: View {
    var selection: TimerMode
    var onSelect: (TimerMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TimerMode.allCases) { mode in
                let selected = mode == selection
                Button { onSelect(mode) } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: selected ? .bold : .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(.black.opacity(selected ? 0.15 : 0))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Round check button for tasks.
struct CheckCircle: View {
    var isDone: Bool
    var tint: Color
    var size: CGFloat = 24
    /// Outlined style for native (non-colored) backgrounds such as the popover.
    var outlined = false

    var body: some View {
        ZStack {
            if outlined && !isDone {
                Circle().strokeBorder(.secondary, lineWidth: 1.5)
            } else {
                Circle().fill(isDone ? tint : Color(white: 0.87))
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

/// Translucent white square button, like the ⋮ buttons on pomofocus.
struct TranslucentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 28, minHeight: 28)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .contentShape(Rectangle())
    }
}

/// Borderless button that gets a soft background on hover. Used in the popover footer.
struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : hovering ? 0.07 : 0))
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

/// Dark rounded "Save" button from the pomofocus task editor.
struct DarkPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(white: configuration.isPressed ? 0.3 : 0.13))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

/// Integer field with ▲/▼ buttons, like pomofocus's "Est Pomodoros" input.
struct NumberBox: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 6) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Ink.primary)
                .frame(width: 46)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Ink.field))
                .onChange(of: value) { _, newValue in
                    let clamped = newValue.clamped(to: range)
                    if clamped != newValue { value = clamped }
                }
            stepButton("arrowtriangle.up.fill", help: "Increase") { value = min(value + 1, range.upperBound) }
            stepButton("arrowtriangle.down.fill", help: "Decrease") { value = max(value - 1, range.lowerBound) }
        }
    }

    private func stepButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(Ink.secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// "Pomos 3/8 · Finish at 16:10 (2.4h)", the summary pomofocus shows under the task list.
struct EstimateSummary: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(TaskStore.self) private var tasks

    var body: some View {
        // Refresh now and then so the finish time keeps up with the clock while the timer is idle.
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text("Pomos:").opacity(0.75)
                    Text("\(tasks.totalCompletedPomodoros)/\(tasks.totalEstimatedPomodoros)")
                        .monospacedDigit()
                }
                if let estimate = engine.finishEstimate() {
                    HStack(spacing: 4) {
                        Text("Finish At:").opacity(0.75)
                        Text(estimate.finishDate, style: .time)
                        Text("(\(Self.hours(estimate.duration)))").monospacedDigit()
                    }
                }
            }
        }
    }

    static func hours(_ duration: TimeInterval) -> String {
        String(format: "%.1fh", duration / 3600)
    }
}

extension TimeInterval {
    /// "1h 25m", "40m" or "0m".
    var focusDurationText: String {
        let minutes = Int(self / 60)
        let hours = minutes / 60
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}
