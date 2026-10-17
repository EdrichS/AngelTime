import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var engine
    @Environment(NotificationService.self) private var notifications

    let alarm: AlarmPlayer

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            // MARK: Timer
            Section {
                ForEach(TimerMode.allCases) { mode in
                    DurationRow(mode: mode)
                }

                LabeledContent("Presets") {
                    HStack(spacing: 6) {
                        ForEach(DurationPreset.all) { preset in
                            Button(preset.label) { settings.apply(preset) }
                                .help("\(preset.name): \(preset.pomodoro) min focus, \(preset.shortBreak) min short break, \(preset.longBreak) min long break")
                        }
                    }
                    .controlSize(.small)
                }

                LabeledContent("Long break interval") {
                    HStack(spacing: 6) {
                        Text("every \(settings.longBreakInterval) pomodoro\(settings.longBreakInterval == 1 ? "" : "s")")
                            .monospacedDigit()
                        Stepper("Long break interval", value: $settings.longBreakInterval, in: AppSettings.longBreakIntervalRange)
                            .labelsHidden()
                    }
                }

                Toggle("Auto start breaks", isOn: $settings.autoStartBreaks)
                Toggle("Auto start pomodoros", isOn: $settings.autoStartPomodoros)
            } header: {
                Label("Timer", systemImage: "clock")
            } footer: {
                Text(engine.hasStarted
                     ? "A session is in progress. New lengths apply from the next session."
                     : "Lengths are in minutes and apply right away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Tasks
            Section {
                Toggle(isOn: $settings.autoCheckTasks) {
                    Text("Auto check tasks")
                    Text("Mark a task done when its pomodoros reach the estimate.")
                }
                Toggle(isOn: $settings.checkToBottom) {
                    Text("Check to bottom")
                    Text("Move finished tasks to the bottom of the list.")
                }
            } header: {
                Label("Tasks", systemImage: "checklist")
            }

            // MARK: Sound
            Section {
                LabeledContent("Alarm sound") {
                    HStack(spacing: 8) {
                        Picker("Alarm sound", selection: $settings.alarmSound) {
                            Text("None").tag(AppSettings.noSound)
                            Divider()
                            ForEach(AlarmPlayer.systemSounds, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button {
                            alarm.play(settings.alarmSound, volume: settings.alarmVolume, repeats: 1)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .disabled(settings.alarmSound == AppSettings.noSound)
                        .help("Preview")
                    }
                }
                LabeledContent("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $settings.alarmVolume, in: 0...1)
                            .frame(width: 160)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                .disabled(settings.alarmSound == AppSettings.noSound)
                LabeledContent("Repeat") {
                    HStack(spacing: 6) {
                        Text("\(settings.alarmRepeat)×").monospacedDigit()
                        Stepper("Repeat", value: $settings.alarmRepeat, in: AppSettings.alarmRepeatRange)
                            .labelsHidden()
                    }
                }
                .disabled(settings.alarmSound == AppSettings.noSound)
            } header: {
                Label("Sound", systemImage: "speaker.wave.2")
            }

            // MARK: Notifications
            Section {
                Toggle("Notify when a session ends", isOn: $settings.notifyOnEnd)
                    .onChange(of: settings.notifyOnEnd) { _, enabled in
                        if enabled { notifications.requestAuthorization() }
                    }
                Picker("Reminder", selection: $settings.reminderMinutes) {
                    ForEach(ReminderOption.allCases) { Text($0.label).tag($0.rawValue) }
                }
                if notifications.authorizationStatus == .denied {
                    HStack {
                        Label("Notifications are turned off for AngelTime.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        Spacer()
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            } header: {
                Label("Notifications", systemImage: "bell")
            }

            // MARK: Appearance
            Section {
                Toggle("Show timer in menu bar", isOn: $settings.showTimeInMenuBar)
                ForEach(TimerMode.allCases) { mode in
                    LabeledContent(mode.title) {
                        SwatchPicker(selection: Binding(
                            get: { settings.colorID(for: mode) },
                            set: { settings.setColorID($0, for: mode) }
                        ))
                    }
                }
            } header: {
                Label("Appearance", systemImage: "paintpalette")
            }

            // MARK: General
            Section {
                Toggle("Keep Tasks window on top", isOn: $settings.tasksWindowOnTop)
                Toggle(isOn: $settings.showInDock) {
                    Text("Show in Dock")
                    Text("AngelTime lives in the menu bar. Turn this on to also get a Dock icon.")
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard enabled != LaunchAtLogin.isEnabled else { return }
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                        } catch {
                            launchAtLoginError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                HStack {
                    Spacer()
                    Button("Reset All Settings…") { confirmReset = true }
                }
            } header: {
                Label("General", systemImage: "gearshape")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 400, idealHeight: 680)
        .onAppear {
            notifications.refreshStatus()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .alert("Couldn't change the login item", isPresented: Binding(
            get: { launchAtLoginError != nil },
            set: { if !$0 { launchAtLoginError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAtLoginError ?? "")
        }
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset Settings", role: .destructive) { settings.resetToDefaults() }
        } message: {
            Text("Your tasks and today's progress are kept.")
        }
    }
}

/// Minutes field + stepper for one session type.
private struct DurationRow: View {
    let mode: TimerMode
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let minutes = Binding(
            get: { settings.minutes(for: mode) },
            set: { settings.setMinutes($0, for: mode) }
        )
        let range = AppSettings.range(for: mode)

        LabeledContent {
            HStack(spacing: 6) {
                TextField(mode.title, value: minutes, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                Stepper(mode.title, value: minutes, in: range)
                    .labelsHidden()
                Text("min")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(settings.color(for: mode))
                    .frame(width: 10, height: 10)
                Text(mode.title)
            }
        }
        .help("\(range.lowerBound)–\(range.upperBound) minutes")
    }
}

private struct SwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ThemePalette.colors) { swatch in
                let selected = swatch.id == selection
                Button {
                    selection = swatch.id
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2).padding(2).opacity(selected ? 1 : 0))
                        .overlay(Circle().strokeBorder(Color.primary.opacity(selected ? 0.45 : 0.1), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(swatch.name)
                .accessibilityLabel(swatch.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
