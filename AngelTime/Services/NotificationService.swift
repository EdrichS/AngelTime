import Foundation
import Observation
import UserNotifications

/// Posts "session finished" and "N minutes left" banners. A finished session's banner has a
/// button that starts the next session.
@Observable
@MainActor
final class NotificationService {
    nonisolated static let startNextActionID = "START_NEXT"
    nonisolated static let sessionEndCategoryID = "SESSION_END"

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored var onStartNext: (() -> Void)?
    @ObservationIgnored private let delegate = NotificationDelegate()
    @ObservationIgnored private var center: UNUserNotificationCenter { .current() }

    func configure() {
        delegate.onStartNext = { [weak self] in self?.onStartNext?() }
        center.delegate = delegate
        let startNext = UNNotificationAction(identifier: Self.startNextActionID, title: "Start Next Session")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.sessionEndCategoryID, actions: [startNext], intentIdentifiers: []),
        ])
        refreshStatus()
    }

    func requestAuthorization() {
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            refreshStatus()
        }
    }

    func refreshStatus() {
        Task {
            authorizationStatus = await center.notificationSettings().authorizationStatus
        }
    }

    func postSessionEnd(_ event: TimerEngine.SessionEvent) {
        let content = UNMutableNotificationContent()
        switch event.finished {
        case .pomodoro:
            content.title = "Pomodoro complete"
            content.body = event.next == .longBreak
                ? "Great work! Time for a long break."
                : "Nice work! Time for a short break."
        case .shortBreak, .longBreak:
            content.title = "Break's over"
            content.body = "Time to focus!"
        }
        if event.nextStartedAutomatically {
            content.body += " The next session has started."
        } else {
            content.categoryIdentifier = Self.sessionEndCategoryID
        }
        post(id: "session-end", content: content)
    }

    func postReminder(mode: TimerMode, minutesLeft: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(minutesLeft) min left"
        content.body = mode == .pomodoro
            ? "Keep going, this pomodoro is almost done."
            : "Your break is ending soon."
        post(id: "reminder", content: content)
    }

    private func post(id: String, content: UNMutableNotificationContent) {
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onStartNext: (@MainActor () -> Void)?

    // Show banners even while AngelTime is the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationService.startNextActionID {
            let startNext = onStartNext
            Task { @MainActor in startNext?() }
        }
        completionHandler()
    }
}
