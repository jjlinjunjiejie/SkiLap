
//  Lap_Widget_ExtensionLiveActivity.swift
//  Lap​Widget​Extension
//
//  SkiLap 实时活动 UI（锁屏 + 灵动岛）
//
//  注意：SkiLapActivityAttributes 在此处独立定义（与主 App 的结构完全一致），
//  ActivityKit 通过类型名匹配两端，Codable 序列化格式相同即可正常通信。
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - ActivityAttributes（与主 App 的 SkiLapActivityAttributes.swift 保持完全一致）
struct SkiLapActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var lapCount: Int
        var lastLapTime: String?
        var skiStateText: String
        var altitude: Double
    }
}

// MARK: - Live Activity Widget 主体
struct Lap_Widget_ExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SkiLapActivityAttributes.self) { context in

            // ── 锁屏 / 通知中心 展示 ──
            SkiLapLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.10, blue: 0.25))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {

                // 展开：Leading
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.skiStateText)
                            .font(.caption)
                    } icon: {
                        Image(systemName: stateIcon(for: context.state.skiStateText))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }

                // 展开：Trailing（圈数 + 海拔）
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("第\(context.state.lapCount)圈")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        Text(String(format: "%+.0f m", context.state.altitude))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // 展开：Bottom（上圈时间）
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let last = context.state.lastLapTime {
                            Label("上圈: \(last)", systemImage: "timer")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        } else {
                            Text("等待首圈计时...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }

            } compactLeading: {
                Image(systemName: stateIcon(for: context.state.skiStateText))
                    .foregroundColor(.cyan)

            } compactTrailing: {
                Text("·\(context.state.lapCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.yellow)

            } minimal: {
                Image(systemName: "figure.skiing.downhill")
                    .foregroundColor(.cyan)
            }
            .widgetURL(URL(string: "skilap://open"))
            .keylineTint(.cyan)
        }
    }

    private func stateIcon(for text: String) -> String {
        if text.contains("缆车") { return "tram.fill" }
        if text.contains("滑行") { return "figure.skiing.downhill" }
        return "snowflake"
    }
}

// MARK: - 锁屏展示视图
struct SkiLapLockScreenView: View {
    let state: SkiLapActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // 左：状态图标 + 文字
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: stateIcon)
                        .font(.title3)
                        .foregroundColor(stateColor)
                    Text(state.skiStateText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(String(format: "相对海拔 %+.0f 米", state.altitude))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // 右：圈数 + 上圈时间
            VStack(alignment: .trailing, spacing: 4) {
                Text("第 \(state.lapCount) 圈")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let last = state.lastLapTime {
                    Text(last)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                } else {
                    Text("— 等待计圈 —")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var stateIcon: String {
        if state.skiStateText.contains("缆车") { return "tram.fill" }
        if state.skiStateText.contains("滑行") { return "figure.skiing.downhill" }
        return "snowflake"
    }

    private var stateColor: Color {
        if state.skiStateText.contains("缆车") { return .orange }
        if state.skiStateText.contains("滑行") { return .cyan }
        return .gray
    }
}

// MARK: - Xcode Preview
extension SkiLapActivityAttributes {
    fileprivate static var preview: SkiLapActivityAttributes {
        SkiLapActivityAttributes()
    }
}

extension SkiLapActivityAttributes.ContentState {
    fileprivate static var skiing: SkiLapActivityAttributes.ContentState {
        .init(lapCount: 3, lastLapTime: "8分22秒", skiStateText: "滑行中 🎿", altitude: -120.5)
    }
    fileprivate static var onLift: SkiLapActivityAttributes.ContentState {
        .init(lapCount: 3, lastLapTime: "8分22秒", skiStateText: "乘缆车中 🚡", altitude: 45.2)
    }
}

#Preview("锁屏", as: .content, using: SkiLapActivityAttributes.preview) {
    Lap_Widget_ExtensionLiveActivity()
} contentStates: {
    SkiLapActivityAttributes.ContentState.skiing
    SkiLapActivityAttributes.ContentState.onLift
}
