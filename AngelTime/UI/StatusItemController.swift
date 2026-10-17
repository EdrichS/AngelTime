import AppKit
import SwiftUI

/// The menu bar icon. Left-click opens the popover. Right-click (or Control-click) shows a
/// quick-actions menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let engine: TimerEngine
    private let tasks: TaskStore
    private let settings: AppSettings

    var showTasksWindow: () -> Void = {}
    var showSettingsWindow: () -> Void = {}

    init(engine: TimerEngine, tasks: TaskStore, settings: AppSettings) {
        self.engine = engine
        self.tasks = tasks
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let root = PopoverView(
            onOpenTasks: { [weak self] in self?.showTasksWindow() },
            onOpenSettings: { [weak self] in self?.showSettingsWindow() },
            onQuit: { NSApp.terminate(nil) }
        )
        .environment(engine)
        .environment(tasks)
        .environment(settings)

        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        observeAndApply { [weak self] in self?.refreshButton() }
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        engine.rollOverDayIfNeeded()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: Button

    private func refreshButton() {
        guard let button = statusItem.button else { return }
        let paused = engine.hasStarted && !engine.isRunning
        let symbol = paused ? "pause.circle" : engine.mode.symbolName
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "AngelTime")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        image?.isTemplate = true
        button.image = image

        if settings.showTimeInMenuBar {
            // Monospaced digits keep the item from changing width every second.
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
            button.attributedTitle = NSAttributedString(string: " " + engine.timeString, attributes: [.font: font])
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }

        let state = engine.isRunning ? "running" : paused ? "paused" : "ready"
        button.toolTip = "AngelTime: \(engine.mode.title) \(engine.timeString) (\(state))"
        button.setAccessibilityLabel("AngelTime, \(engine.mode.title), \(engine.timeString), \(state)")
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            closePopover()
            showQuickMenu()
        } else if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    // MARK: Right-click menu

    private func showQuickMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let header = NSMenuItem(title: "\(engine.mode.title): \(engine.timeString)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if let task = tasks.activeTask, engine.mode == .pomodoro {
            let taskItem = NSMenuItem(title: task.title, action: nil, keyEquivalent: "")
            taskItem.isEnabled = false
            taskItem.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
            menu.addItem(taskItem)
        }
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(
            engine.isRunning ? "Pause" : (engine.hasStarted ? "Resume" : "Start"),
            symbol: engine.isRunning ? "pause.fill" : "play.fill"
        ) { [weak self] in self?.engine.toggle() })

        let reset = ClosureMenuItem("Reset", symbol: "arrow.counterclockwise") { [weak self] in self?.engine.reset() }
        reset.isEnabled = engine.hasStarted
        menu.addItem(reset)

        let skip = ClosureMenuItem("Skip to Next", symbol: "forward.end.fill") { [weak self] in self?.engine.skip() }
        skip.isEnabled = engine.hasStarted
        menu.addItem(skip)

        let switchItem = NSMenuItem(title: "Switch To", action: nil, keyEquivalent: "")
        let switchMenu = NSMenu()
        for mode in TimerMode.allCases {
            let item = ClosureMenuItem("\(mode.title) (\(settings.minutes(for: mode)) min)") { [weak self] in
                self?.engine.switchTo(mode)
            }
            item.state = engine.mode == mode ? .on : .off
            switchMenu.addItem(item)
        }
        switchItem.submenu = switchMenu
        menu.addItem(switchItem)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Show All Tasks", symbol: "checklist") { [weak self] in self?.showTasksWindow() })
        menu.addItem(ClosureMenuItem("Timer Lengths…", symbol: "timer") { [weak self] in self?.showSettingsWindow() })
        menu.addItem(ClosureMenuItem("Settings…", symbol: "gearshape") { [weak self] in self?.showSettingsWindow() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit AngelTime") { NSApp.terminate(nil) })

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Hand clicks back to the button action so the next left-click opens the popover.
        statusItem.menu = nil
    }
}

/// An `NSMenuItem` that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() {
        handler()
    }
}
