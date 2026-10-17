import SwiftUI
import WidgetKit

@main
struct AngelTimeWidgets: WidgetBundle {
    var body: some Widget {
        TimerWidget()
    }
}

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.widgetKind, provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
        }
        .configurationDisplayName("AngelTime")
        .description("The current session with a live countdown, your active task and today's pomodoros.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// False when there's no shared state to read: the app hasn't run yet, or it isn't signed
    /// with a team, so the widget can't open the App Group container.
    var isConnected = true
}

/// The app reloads the timeline on every change, so a timeline only has to cover the time until
/// the next one: the countdown is drawn live by `Text(timerInterval:)`, with extra entries for when
/// the session runs out and for midnight, when today's count resets.
struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        let stored = WidgetSnapshotStore.load()
        completion(TimerEntry(date: .now, snapshot: stored ?? .placeholder, isConnected: stored != nil || context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let now = Date()
        let stored = WidgetSnapshotStore.load()
        let snapshot = stored ?? .placeholder

        var dates = [now]
        if snapshot.isCountingDown(at: now), let endDate = snapshot.endDate {
            dates.append(endDate)
        }
        let calendar = Calendar.current
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(midnight)
        }

        let entries = dates.sorted().map {
            TimerEntry(date: $0, snapshot: snapshot, isConnected: stored != nil)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
