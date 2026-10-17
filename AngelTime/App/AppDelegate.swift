import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings!
    private var tasks: TaskStore!
    private var engine: TimerEngine!
    private var alarm: AlarmPlayer!
    private var notifications: NotificationService!
    private var windows: WindowManager!
    private var statusItem: StatusItemController!
    private var widgetBridge: WidgetBridge!
    /// Widget commands that arrived by URL before the timer was set up.
    private var pendingWidgetCommands: [WidgetCommand] = []

    private static let hasLaunchedKey = "app.hasLaunchedBefore"

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted in the app. Don't put up any UI for them.
        guard !isRunningTests else { return }

        settings = AppSettings()
        tasks = TaskStore(settings: settings)
        engine = TimerEngine(settings: settings, tasks: tasks)
        alarm = AlarmPlayer()
        notifications = NotificationService()
        notifications.configure()

        windows = WindowManager(engine: engine, tasks: tasks, settings: settings, notifications: notifications, alarm: alarm)
        statusItem = StatusItemController(engine: engine, tasks: tasks, settings: settings)
        statusItem.showTasksWindow = { [weak self] in self?.windows.showTasks() }
        statusItem.showSettingsWindow = { [weak self] in self?.windows.showSettings() }
        windows.willShowWindow = { [weak self] in self?.statusItem.closePopover() }

        engine.onSessionEnd = { [weak self] event in self?.sessionDidEnd(event) }
        engine.onReminder = { [weak self] mode, minutes in
            guard let self, settings.notifyOnEnd else { return }
            notifications.postReminder(mode: mode, minutesLeft: minutes)
        }
        notifications.onStartNext = { [weak self] in self?.engine.start() }

        widgetBridge = WidgetBridge(engine: engine, tasks: tasks, settings: settings)
        pendingWidgetCommands.forEach(widgetBridge.perform)
        pendingWidgetCommands = []

        NSApp.mainMenu = MainMenu.make()

        observeAndApply { [weak self] in
            guard let self else { return }
            NSApp.setActivationPolicy(settings.showInDock ? .regular : .accessory)
        }

        // The timer runs on wall-clock time. Re-check it as soon as the Mac wakes up.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.tick() }
        }

        if settings.notifyOnEnd {
            notifications.requestAuthorization()
        }

        // A menu bar app is easy to miss, so show the Tasks window on first launch.
        if !UserDefaults.standard.bool(forKey: Self.hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
            windows.showTasks()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windows?.showTasks() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        widgetBridge?.publishQuit()
    }

    /// The widget's buttons open `angeltime://toggle` or `angeltime://skip` when the app isn't
    /// running. A launch can deliver the URL before setup finishes, so hold on to it until then.
    func application(_ application: NSApplication, open urls: [URL]) {
        for command in urls.compactMap(WidgetCommand.init(url:)) {
            if let widgetBridge {
                widgetBridge.perform(command)
            } else {
                pendingWidgetCommands.append(command)
            }
        }
    }

    private func sessionDidEnd(_ event: TimerEngine.SessionEvent) {
        guard !event.skipped else { return }
        alarm.play(settings.alarmSound, volume: settings.alarmVolume, repeats: settings.alarmRepeat)
        if settings.notifyOnEnd {
            notifications.postSessionEnd(event)
        }
    }

    // MARK: Menu actions

    @objc func showSettingsWindow(_ sender: Any?) { windows.showSettings() }
    @objc func showTasksWindow(_ sender: Any?) { windows.showTasks() }
    @objc func toggleTimer(_ sender: Any?) { engine.toggle() }
    @objc func resetTimer(_ sender: Any?) { engine.reset() }
    @objc func skipSession(_ sender: Any?) { engine.skip() }
    @objc func switchToPomodoro(_ sender: Any?) { engine.switchTo(.pomodoro) }
    @objc func switchToShortBreak(_ sender: Any?) { engine.switchTo(.shortBreak) }
    @objc func switchToLongBreak(_ sender: Any?) { engine.switchTo(.longBreak) }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let engine else { return true }
        switch item.action {
        case #selector(toggleTimer(_:)):
            item.title = engine.isRunning ? "Pause" : (engine.hasStarted ? "Resume" : "Start")
            return true
        case #selector(resetTimer(_:)), #selector(skipSession(_:)):
            return engine.hasStarted
        case #selector(switchToPomodoro(_:)):
            item.state = engine.mode == .pomodoro ? .on : .off
        case #selector(switchToShortBreak(_:)):
            item.state = engine.mode == .shortBreak ? .on : .off
        case #selector(switchToLongBreak(_:)):
            item.state = engine.mode == .longBreak ? .on : .off
        default:
            break
        }
        return true
    }
}
