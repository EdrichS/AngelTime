import SwiftUI

/// Mode tabs, the big countdown and the START/PAUSE button. Shared by the popover and the
/// Tasks window.
struct TimerCard: View {
    enum Style {
        /// Solid mode-colored card on a native popover background.
        case popover
        /// Translucent card on a mode-colored window, like pomofocus.
        case window
    }

    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    var style: Style

    var body: some View {
        let tint = settings.color(for: engine.mode)

        VStack(spacing: 4) {
            ModeTabs(selection: engine.mode) { engine.switchTo($0) }

            Text(engine.timeString)
                .font(.system(size: style == .popover ? 66 : 68, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.25), value: engine.secondsLeft)
                .accessibilityLabel("\(engine.mode.title), \(engine.timeString) remaining")

            HStack(spacing: 16) {
                RoundIconButton(systemName: "arrow.counterclockwise", help: "Reset timer") {
                    engine.reset()
                }
                .opacity(engine.hasStarted ? 1 : 0)
                .disabled(!engine.hasStarted)

                Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
                    .buttonStyle(ChunkyButtonStyle(tint: tint, engaged: engine.isRunning))

                RoundIconButton(systemName: "forward.end.fill", help: "Skip to the next session") {
                    engine.skip()
                }
                .opacity(engine.hasStarted ? 1 : 0)
                .disabled(!engine.hasStarted)
            }

            ProgressTrack(progress: engine.progress)
                .padding(.top, 8)
                .padding(.horizontal, 6)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style == .popover ? tint : .white.opacity(0.1))
        }
        .animation(.easeInOut(duration: 0.4), value: engine.mode)
    }
}

private struct ProgressTrack: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.12))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: proxy.size.width * progress)
                    .animation(.linear(duration: 0.25), value: progress)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
