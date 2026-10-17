# AngelTime

A native macOS Pomodoro timer for the menu bar, inspired by [pomofocus.io](https://pomofocus.io).
See [brainstorm.txt](brainstorm.txt) for the research and design process.

## Features

- **Menu bar timer.** Shows the countdown (`⏱ 24:13`) with an icon for each mode. Left-click
  opens the popover. Right-click gives quick actions: start/pause, reset, skip, switch mode,
  timer lengths, settings and quit.
- **Popover.** Mode tabs, a large countdown, pomofocus's chunky START/PAUSE button, the
  active task, the next five tasks, a quick-add field and a "finish at" estimate.
- **Tasks window.** A small window in the mode's color with a compact timer and every task.
  To-do tasks can be reordered by dragging. Completed tasks sit in a collapsible section.
  Edit tasks inline (title, est/act pomodoros, note). Clear finished tasks, clear act
  pomodoros or delete all.
- **Custom session lengths.** Set the Pomodoro, Short Break and Long Break minutes, with
  steppers and presets (25·5·15, 50·10·20, 90·15·30). If the timer is idle the change applies
  right away. Otherwise it applies from the next session.
- Long-break interval, auto-start breaks and pomodoros, auto-check tasks, check to bottom
- Alarm sound (macOS system sounds), volume and repeat
- Notifications when a session ends (with a "Start Next Session" button), plus an optional
  "N minutes left" reminder
- A theme color for each mode, an option to keep the Tasks window on top, a Dock icon toggle
  and launch at login
- Daily stats: pomodoros finished today and minutes focused
- **Widget.** A small and a medium desktop / Notification Center widget with a live countdown
  and START/PAUSE and Skip buttons. It needs a signing team, see [Widget](#widget).

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later (built with Xcode 26.3)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional), only needed if you change
  `project.yml`

## Build & run

```bash
./scripts/build.sh
```

```bash
open build/AngelTime.app
```

You can also open `AngelTime.xcodeproj` in Xcode and press ⌘R. Run the tests with
`./scripts/build.sh test` or ⌘U.

To keep the app, copy `build/AngelTime.app` to `/Applications`. By default the build is signed
ad-hoc ("Sign to Run Locally"), so it runs on this Mac without a developer account. The widget
is the one part that needs a team, see [Signing for the widget](#signing-for-the-widget).

## Widget

AngelTime comes with a WidgetKit widget in two sizes, small and medium. It shows:

- the current mode (Pomodoro, Short Break or Long Break) on that mode's theme color
- the countdown, live while the timer runs and still while it's paused or idle, over a progress bar
- the active task, or "Time to focus!" / "Time for a break!" when there isn't one
- how many pomodoros you've finished today
- START/PAUSE, plus Skip once the session has started

To add it, right-click the desktop, choose **Edit Widgets…** and search for AngelTime. You can
also add it from Notification Center.

**How it works.** The app is the only thing that runs the timer. When the mode, running state,
active task, today's count or a theme color changes, the app writes a small JSON snapshot
(`widget-state.json`) to the App Group container and asks WidgetKit to reload. The countdown
uses `Text(timerInterval:)`, so the widget doesn't reload every second. The buttons are App
Intents in the widget, and they hand the command to the app with a Darwin notification
(`com.edrich.AngelTime.widget.toggle` or `.skip`). If the app isn't running, they open
`angeltime://toggle` (or `angeltime://skip`) instead, which launches it and runs the command.
Quitting the app resets the widget to an idle Pomodoro, which is how the app starts next time.

### Signing for the widget

macOS only loads widgets that are sandboxed, so the widget can't read the app's files directly.
It reads the timer from a shared App Group container, and macOS only lets it in when the app and
the widget are signed by your Apple developer team. An ad-hoc build still compiles and runs, but
the widget can't see the timer. It shows an idle 25:00 with "Open AngelTime".

To sign with your team:

1. In Xcode, open **Settings → Accounts** and make sure your Apple ID and team are listed.
2. Find your 10-character Team ID: select the team in **Settings → Accounts**, or look under
   Membership on [developer.apple.com/account](https://developer.apple.com/account).
3. In `project.yml`, set it in the project-wide settings. This is the only change you need:

   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: "ABCDE12345"   # your Team ID
   ```

   `CODE_SIGN_IDENTITY` isn't set in `project.yml`, so Xcode switches from "-" to
   "Apple Development" on its own. `APP_GROUP_ID` becomes `ABCDE12345.com.edrich.AngelTime`.
   A group ID that starts with the team ID doesn't need a provisioning profile on macOS.
4. Run `./scripts/build.sh`. It passes `-allowProvisioningUpdates`, so the first build can create
   your Apple Development certificate. In Xcode, the same happens when you press ⌘R.
5. Copy `build/AngelTime.app` to `/Applications`, open it, then add the widget.

If the widget doesn't show up in the gallery, or still shows "Open AngelTime", quit and reopen
AngelTime. You can also check that macOS sees the extension:

```bash
pluginkit -m -v -i com.edrich.AngelTime.Widget
```

## Keyboard shortcuts (while an AngelTime window is focused)

| Shortcut | Action |
| --- | --- |
| ⌘↩ | Start / pause |
| ⌘R | Reset |
| ⌘→ | Skip to next session |
| ⌘1 / ⌘2 / ⌘3 | Pomodoro / Short Break / Long Break |
| ⌘N | Add a task (Tasks window) |
| ⌘0 | Show the Tasks window |
| ⌘, | Settings |

## Project layout

```
AngelTime/
  App/        entry point, AppDelegate, main menu
  Models/     TimerMode, PomoTask, AppSettings, ThemePalette
  Stores/     TimerEngine (state machine), TaskStore (tasks + persistence)
  Services/   alarm sound, notifications, launch at login, Observation bridge, widget bridge
  UI/         NSStatusItem + NSPopover controller, window manager
  Views/      SwiftUI views (popover, Tasks window, task row/editor, settings)
AngelTimeWidget/ WidgetKit extension: timeline provider, small/medium views, App Intents
Shared/       code built into the app and the widget: snapshot model, App Group storage,
              widget commands (TimerMode and ThemePalette are shared too)
AngelTimeTests/  engine, task store and widget snapshot unit tests
scripts/      build.sh, make_icon.swift (renders the app icon)
```

Data lives in `~/Library/Application Support/AngelTime/tasks.json`. Settings are stored in the
`com.edrich.AngelTime` defaults domain. With a signing team, the widget's snapshot is in
`~/Library/Group Containers/<TeamID>.com.edrich.AngelTime/widget-state.json`.
