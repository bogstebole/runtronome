//
//  RuntronomeWidgetLiveActivity.swift
//  RuntronomeWidget
//
//  Created by Bogdan Stefanovic on 22. 6. 2026..
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RuntronomeWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct RuntronomeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RuntronomeWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension RuntronomeWidgetAttributes {
    fileprivate static var preview: RuntronomeWidgetAttributes {
        RuntronomeWidgetAttributes(name: "World")
    }
}

extension RuntronomeWidgetAttributes.ContentState {
    fileprivate static var smiley: RuntronomeWidgetAttributes.ContentState {
        RuntronomeWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: RuntronomeWidgetAttributes.ContentState {
         RuntronomeWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: RuntronomeWidgetAttributes.preview) {
   RuntronomeWidgetLiveActivity()
} contentStates: {
    RuntronomeWidgetAttributes.ContentState.smiley
    RuntronomeWidgetAttributes.ContentState.starEyes
}
