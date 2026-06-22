import WidgetKit
import SwiftUI

private let suiteName = "group.com.bogste.runtronome"

struct RuntronomeEntry: TimelineEntry {
    let date: Date
    let spm: Int
    let alertFrequency: String
    let phaseLabel: String
    let isGarminConnected: Bool
}

struct RuntronomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> RuntronomeEntry {
        RuntronomeEntry(date: Date(), spm: 175, alertFrequency: "EVERY OTHER", phaseLabel: "WARM UP", isGarminConnected: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RuntronomeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RuntronomeEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> RuntronomeEntry {
        let d = UserDefaults(suiteName: suiteName)
        let spm = d?.integer(forKey: "spm") ?? 0
        return RuntronomeEntry(
            date: Date(),
            spm: spm == 0 ? 175 : spm,
            alertFrequency: d?.string(forKey: "alertFrequency") ?? "EVERY OTHER",
            phaseLabel: d?.string(forKey: "phaseLabel") ?? "",
            isGarminConnected: d?.bool(forKey: "isGarminConnected") ?? false
        )
    }
}

struct RuntronomeWidgetEntryView: View {
    var entry: RuntronomeProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularView
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            Text("\(entry.spm) SPM")
        default:
            circularView
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.spm)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("SPM")
                    .font(.system(size: 13, weight: .regular))
                    .opacity(0.55)
            }
            Text(entry.alertFrequency)
                .font(.system(size: 11, weight: .regular))
                .opacity(0.6)
            if entry.isGarminConnected && !entry.phaseLabel.isEmpty {
                Text(entry.phaseLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.9)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var circularView: some View {
        VStack(spacing: 1) {
            Text("\(entry.spm)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("SPM")
                .font(.system(size: 9, weight: .regular))
                .opacity(0.65)
        }
    }
}

struct RuntronomeWidget: Widget {
    let kind = "RuntronomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RuntronomeProvider()) { entry in
            RuntronomeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Runtronome")
        .description("Current SPM and training phase.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .accessoryRectangular) {
    RuntronomeWidget()
} timeline: {
    RuntronomeEntry(date: .now, spm: 175, alertFrequency: "EVERY OTHER", phaseLabel: "WARM UP", isGarminConnected: true)
    RuntronomeEntry(date: .now, spm: 180, alertFrequency: "EVERY STEP", phaseLabel: "", isGarminConnected: false)
}
