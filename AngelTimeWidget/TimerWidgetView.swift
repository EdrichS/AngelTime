import SwiftUI
import WidgetKit

/// A widget version of the popover's TimerCard: white type on the mode's theme color, the big
/// countdown and pomofocus's chunky START/PAUSE button.
struct TimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimerEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var tint: Color { ThemePalette.color(id: snapshot.colorID(for: snapshot.mode)) }

    var body: some View {
        Group {
            if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .foregroundStyle(.white)
        .containerBackground(tint, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ModeLabel(mode: snapshot.mode)
                Spacer(minLength: 0)
                TodayCount(count: snapshot.completedPomodoros(on: entry.date), compact: true)
            }
            Spacer(minLength: 2)
            Countdown(entry: entry, size: 40)
            SessionProgress(entry: entry)
                .padding(.top, 3)
            Spacer(minLength: 6)
            Text(caption)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .opacity(0.9)
            Controls(entry: entry, tint: tint, height: 26)
                .padding(.top, 6)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                ModeLabel(mode: snapshot.mode)
                Spacer(minLength: 2)
                Countdown(entry: entry, size: 50)
                SessionProgress(entry: entry)
                    .padding(.top, 4)
                Spacer(minLength: 8)
                Controls(entry: entry, tint: tint, height: 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.taskTitle == nil ? " " : "Working on")
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .opacity(0.7)
                Text(caption)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(3)
                Spacer(minLength: 4)
                TodayCount(count: snapshot.completedPomodoros(on: entry.date), compact: false)
            }
            .frame(width: 118, alignment: .leading)
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1)
            }
        }
    }

    /// The active task, or pomofocus's "Time to focus!" line when there isn't one.
    private var caption: String {
        guard entry.isConnected else { return "Open AngelTime" }
        return snapshot.taskTitle ?? snapshot.mode.message
    }
}

/// The selected tab from the app's ModeTabs.
private struct ModeLabel: View {
    let mode: TimerMode

    var body: some View {
        Text(mode.title)
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.black.opacity(0.15)))
    }
}

private struct TodayCount: View {
    let count: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
            Text(compact ? "\(count)" : "\(count) today")
                .monospacedDigit()
        }
        .font(.system(size: compact ? 12 : 13, weight: .bold))
        .opacity(0.9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) pomodoros today")
    }
}

/// Counts down live while the timer runs. Paused, idle and finished timers go through the same
/// view with a pause time, so the digits look the same in every state.
private struct Countdown: View {
    let entry: TimerEntry
    let size: CGFloat

    var body: some View {
        let snapshot = entry.snapshot
        let running = snapshot.isCountingDown(at: entry.date)
        let end = running ? snapshot.endDate! : entry.date.addingTimeInterval(TimeInterval(snapshot.secondsLeft(at: entry.date)))

        Text(timerInterval: entry.date...end, pauseTime: running ? nil : entry.date, countsDown: true, showsHours: false)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// The progress track from the TimerCard. It fills up live while the timer runs.
private struct SessionProgress: View {
    let entry: TimerEntry

    var body: some View {
        let snapshot = entry.snapshot
        Group {
            if snapshot.isCountingDown(at: entry.date), let end = snapshot.endDate, snapshot.sessionDuration > 0 {
                ProgressView(
                    timerInterval: end.addingTimeInterval(-snapshot.sessionDuration)...end,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
            } else {
                ProgressView(value: snapshot.progress(at: entry.date))
            }
        }
        .progressViewStyle(.linear)
        .tint(.white.opacity(0.9))
        .accessibilityHidden(true)
    }
}

/// START/PAUSE, plus skip once the session has started (like the TimerCard).
private struct Controls: View {
    let entry: TimerEntry
    let tint: Color
    let height: CGFloat

    var body: some View {
        let snapshot = entry.snapshot
        HStack(spacing: 6) {
            Button(intent: ToggleTimerIntent()) {
                ChunkyLabel(
                    title: snapshot.isCountingDown(at: entry.date) ? "Pause" : "Start",
                    tint: tint,
                    engaged: snapshot.isCountingDown(at: entry.date),
                    height: height
                )
            }
            .buttonStyle(.plain)

            if snapshot.hasStarted {
                Button(intent: SkipSessionIntent()) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: height, height: height)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip to the next session")
            }
        }
    }
}

/// A still version of the app's ChunkyButtonStyle: a white face on a gray lip, pressed down while
/// the timer runs.
private struct ChunkyLabel: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let title: String
    let tint: Color
    let engaged: Bool
    let height: CGFloat

    private let lip: CGFloat = 3

    var body: some View {
        // Desktop widgets turn monochrome when another app is in front. Tinted type on a white
        // face would wash out, so use white type on a translucent face then.
        let vibrant = renderingMode == .vibrant
        Text(title)
            .font(.system(size: height * 0.5, weight: .bold, design: .rounded))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(vibrant ? .white : tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(vibrant ? 0.25 : 1)))
            .offset(y: engaged ? lip : 0)
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(white: 0.88))
                    .frame(height: height)
                    .offset(y: lip)
                    .opacity(engaged || vibrant ? 0 : 1)
            }
            .frame(height: height + lip, alignment: .top)
    }
}

#Preview("Running", as: .systemSmall) {
    TimerWidget()
} timeline: {
    TimerEntry(date: .now, snapshot: .preview(running: true))
    TimerEntry(date: .now, snapshot: .preview(running: false))
}

#Preview("Medium", as: .systemMedium) {
    TimerWidget()
} timeline: {
    TimerEntry(date: .now, snapshot: .preview(running: true))
}

extension WidgetSnapshot {
    static func preview(running: Bool) -> WidgetSnapshot {
        var snapshot = WidgetSnapshot.placeholder
        snapshot.isRunning = running
        snapshot.hasStarted = true
        snapshot.endDate = running ? Date().addingTimeInterval(14 * 60 + 32) : nil
        snapshot.secondsLeft = running ? nil : 14 * 60 + 32
        snapshot.taskTitle = "Write the quarterly report"
        snapshot.completedToday = 3
        snapshot.statsDay = Date()
        return snapshot
    }
}
