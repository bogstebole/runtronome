import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct RuntronomeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spm: Int
        var alertFrequency: String
        var phaseLabel: String
    }

    let trainingTitle: String
    let isGarminConnected: Bool
}

struct RuntronomeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RuntronomeActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color(white: 0.1))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.spm)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("SPM")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.attributes.isGarminConnected && !context.state.phaseLabel.isEmpty {
                            Text(context.state.phaseLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(context.state.alertFrequency)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 8) {
                            Button(intent: DecreaseSPMIntent()) {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.15), in: Circle())
                            }
                            .buttonStyle(.plain)
                            Button(intent: IncreaseSPMIntent()) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.15), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 4)
                }
            } compactLeading: {
                Text("\(context.state.spm)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } compactTrailing: {
                Text(context.state.phaseLabel.isEmpty ? "SPM" : context.state.phaseLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } minimal: {
                Text("\(context.state.spm)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<RuntronomeActivityAttributes>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if context.attributes.isGarminConnected {
                    Text(context.attributes.trainingTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(context.state.spm)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("SPM")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.45))
                }
                Text(context.state.alertFrequency)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(1)
            }
            Spacer()
            VStack(spacing: 10) {
                Button(intent: IncreaseSPMIntent()) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                Button(intent: DecreaseSPMIntent()) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
