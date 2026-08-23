import ActivityKit
import SwiftUI
import WidgetKit

struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            ActivityLockScreenView(content: context.state)
                .activityBackgroundTint(Color(red: 0.07, green: 0.09, blue: 0.20))
                .activitySystemActionForegroundColor(Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityExpandedLeading(content: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityExpandedTrailing(content: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityExpandedBottom(content: context.state)
                }
            } compactLeading: {
                ActivityCompactLeading(content: context.state)
            } compactTrailing: {
                ActivityCompactTrailing(content: context.state)
            } minimal: {
                ActivityMinimal(content: context.state)
            }
        }
    }
}
