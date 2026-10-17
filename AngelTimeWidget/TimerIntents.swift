import AppIntents
import AppKit
import notify

/// The widget's START/PAUSE button.
struct ToggleTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start or Pause Timer"
    static let description = IntentDescription("Starts or pauses the AngelTime timer.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await WidgetCommand.toggle.send()
        return .result()
    }
}

/// The widget's skip button.
struct SkipSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Session"
    static let description = IntentDescription("Ends the current AngelTime session and moves on to the next one.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await WidgetCommand.skip.send()
        return .result()
    }
}

extension WidgetCommand {
    /// Hands the command to the app, which owns the timer. WidgetKit reloads the timeline as soon
    /// as `perform()` returns, so wait (briefly) for the app to publish its new state first.
    func send() async {
        let isAppRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleID).isEmpty
        guard isAppRunning else {
            NSWorkspace.shared.open(url)
            return
        }

        let before = WidgetSnapshotStore.lastModified()
        notify_post(notificationName)
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if WidgetSnapshotStore.lastModified() != before { return }
        }
    }
}
