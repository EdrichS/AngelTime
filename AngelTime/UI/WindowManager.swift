import AppKit
import SwiftUI

/// Creates and reuses the Tasks and Settings windows.
@MainActor
final class WindowManager {
    private let engine: TimerEngine
    private let tasks: TaskStore
    private let settings: AppSettings
    private let notifications: NotificationService
    private let alarm: AlarmPlayer

    private var tasksWindow: NSWindow?
    private var settingsWindow: NSWindow?

    /// Called before a window is shown. Used to close the popover.
    var willShowWindow: () -> Void = {}

    init(engine: TimerEngine, tasks: TaskStore, settings: AppSettings, notifications: NotificationService, alarm: AlarmPlayer) {
        self.engine = engine
        self.tasks = tasks
        self.settings = settings
        self.notifications = notifications
        self.alarm = alarm
    }

    func showTasks() {
        let window = tasksWindow ?? makeTasksWindow()
        tasksWindow = window
        present(window)
    }

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        present(window)
    }

    private func present(_ window: NSWindow) {
        willShowWindow()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeTasksWindow() -> NSWindow {
        let root = TasksWindowView(onOpenSettings: { [weak self] in self?.showSettings() })
            .environment(engine)
            .environment(tasks)
            .environment(settings)

        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.contentMinSize = NSSize(width: 340, height: 500)
        window.setContentSize(NSSize(width: 380, height: 680))
        window.center()
        window.setFrameAutosaveName("AngelTime.TasksWindow")

        // Keep the window's level and its title (shown in Mission Control and the Window menu)
        // in sync with settings and the timer.
        observeAndApply { [weak self, weak window] in
            guard let self, let window else { return }
            window.level = settings.tasksWindowOnTop ? .floating : .normal
            let subtitle = engine.mode == .pomodoro ? (tasks.activeTask?.title ?? engine.mode.message) : engine.mode.message
            window.title = "\(engine.timeString) – \(subtitle)"
        }
        return window
    }

    private func makeSettingsWindow() -> NSWindow {
        let root = SettingsView(alarm: alarm)
            .environment(engine)
            .environment(settings)
            .environment(notifications)

        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.title = "AngelTime Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 460, height: 400)
        window.setContentSize(NSSize(width: 500, height: 680))
        window.center()
        window.setFrameAutosaveName("AngelTime.SettingsWindow")
        return window
    }
}
