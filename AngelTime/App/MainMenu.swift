import AppKit

/// The app's main menu. The menu bar only shows it when "Show in Dock" is on, but key
/// equivalents always go through it. Without an Edit menu, ⌘C/⌘V/⌘A wouldn't work in text fields.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(timerMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.windowsMenu = window
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "AngelTime")
        menu.addItem(withTitle: "About AngelTime", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettingsWindow(_:)), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide AngelTime", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AngelTime", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            .keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func timerMenu() -> NSMenu {
        let menu = NSMenu(title: "Timer")
        menu.addItem(withTitle: "Start", action: #selector(AppDelegate.toggleTimer(_:)), keyEquivalent: "\r")
        menu.addItem(withTitle: "Reset", action: #selector(AppDelegate.resetTimer(_:)), keyEquivalent: "r")
        let rightArrow = String(Character(Unicode.Scalar(UInt16(NSRightArrowFunctionKey))!))
        menu.addItem(withTitle: "Skip to Next", action: #selector(AppDelegate.skipSession(_:)), keyEquivalent: rightArrow)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pomodoro", action: #selector(AppDelegate.switchToPomodoro(_:)), keyEquivalent: "1")
        menu.addItem(withTitle: "Short Break", action: #selector(AppDelegate.switchToShortBreak(_:)), keyEquivalent: "2")
        menu.addItem(withTitle: "Long Break", action: #selector(AppDelegate.switchToLongBreak(_:)), keyEquivalent: "3")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Tasks", action: #selector(AppDelegate.showTasksWindow(_:)), keyEquivalent: "0")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }
}
