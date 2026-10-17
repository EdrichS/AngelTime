import Foundation

/// The timer state the widget shows. The app writes it to the App Group container whenever the
/// timer, the active task or a theme color changes, and the widget builds its timeline from it.
struct WidgetSnapshot: Codable, Equatable {
    var mode: TimerMode
    var isRunning: Bool
    /// True once the current session has been started, until it ends or is reset.
    var hasStarted: Bool
    /// When the running session ends. Nil while paused or idle.
    var endDate: Date?
    /// Whole seconds left while paused or idle. Nil while running (use `endDate`).
    var secondsLeft: Int?
    var sessionDuration: TimeInterval
    var taskTitle: String?
    /// Focus sessions finished on `statsDay`.
    var completedToday: Int
    var statsDay: Date
    /// Theme color ID for each mode, keyed by `TimerMode.rawValue`.
    var colorIDs: [String: String]

    /// What the widget shows before the app has shared any state.
    static let placeholder = WidgetSnapshot(
        mode: .pomodoro,
        isRunning: false,
        hasStarted: false,
        endDate: nil,
        secondsLeft: 25 * 60,
        sessionDuration: 25 * 60,
        taskTitle: nil,
        completedToday: 0,
        statsDay: .distantPast,
        colorIDs: [:]
    )

    func colorID(for mode: TimerMode) -> String {
        colorIDs[mode.rawValue] ?? ThemePalette.defaultID(for: mode)
    }

    /// True while the session is running and hasn't run out at `date`.
    func isCountingDown(at date: Date) -> Bool {
        guard isRunning, let endDate else { return false }
        return endDate > date
    }

    func secondsLeft(at date: Date) -> Int {
        if let endDate {
            return max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
        }
        return secondsLeft ?? Int(sessionDuration)
    }

    /// 0 at the start of a session, 1 at the end.
    func progress(at date: Date) -> Double {
        guard sessionDuration > 0 else { return 0 }
        return min(max(1 - Double(secondsLeft(at: date)) / sessionDuration, 0), 1)
    }

    /// Today's count goes back to 0 after midnight, even if the app hasn't published since.
    func completedPomodoros(on date: Date) -> Int {
        Calendar.current.isDate(statsDay, inSameDayAs: date) ? completedToday : 0
    }
}

/// Reads and writes the snapshot in the App Group container that the app and widget share.
enum WidgetSnapshotStore {
    /// `kind` of the timer widget, used to reload its timelines.
    static let widgetKind = "AngelTimeTimer"

    /// Both Info.plists carry the App Group ID, which project.yml builds from DEVELOPMENT_TEAM.
    /// An ad-hoc build has no team, so its ID starts with "." and there's no group to share.
    static var appGroupID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AngelTimeAppGroup") as? String,
              !id.isEmpty, !id.hasPrefix(".") else { return nil }
        return id
    }

    static var fileURL: URL? {
        guard let appGroupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-state.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let fileURL else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    static func lastModified() -> Date? {
        guard let fileURL else { return nil }
        return (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    // Dates keep their default encoding: ISO 8601 would drop the fraction of a second that
    // `endDate` needs to stay in step with the app's countdown.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static let decoder = JSONDecoder()
}

/// What the widget's buttons ask the app to do. The app owns the timer, so the widget only
/// forwards commands: a Darwin notification while the app runs, or a URL that launches it.
enum WidgetCommand: String, CaseIterable {
    case toggle
    case skip

    static let appBundleID = "com.edrich.AngelTime"
    static let urlScheme = "angeltime"

    /// Darwin notification the widget posts and the running app observes.
    var notificationName: String { "\(Self.appBundleID).widget.\(rawValue)" }

    /// `angeltime://toggle`, for when the app has to be launched first.
    var url: URL { URL(string: "\(Self.urlScheme)://\(rawValue)")! }

    init?(url: URL) {
        guard url.scheme == Self.urlScheme, let host = url.host else { return nil }
        self.init(rawValue: host)
    }
}
