
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

// MARK: - Live Activity Widget 主体
// SkiLapActivityAttributes 已由共享文件 SkiLapActivityAttributes.swift 提供（已加入两个 Target）
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

                // 展开：Trailing（圈数）
                DynamicIslandExpandedRegion(.trailing) {
                    Text("第\(context.state.lapCount)圈")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
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
                // 左側：圈数
                Text("第\(context.state.lapCount)圈")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.8))

            } compactTrailing: {
                // 右側：上一圈时间
                if let last = context.state.lastLapTime {
                    Text(last)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else {
                    Text("--分--秒")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

            } minimal: {
                // 仅显示圈数数字
                Text("\(context.state.lapCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.yellow)
            }
            .widgetURL(URL(string: "skilap://open"))
            .keylineTint(.cyan)
        }
    }

    private func stateIcon(for text: String) -> String {
        if text.contains("缆车") { return "tram.fill" }
        if text.contains("滑行") { return "figure.snowboarding" }
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
        if state.skiStateText.contains("滑行") { return "figure.snowboarding" }
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
        .init(lapCount: 3, lastLapTime: "8分22秒", skiStateText: "滑行中 🎿")
    }
    fileprivate static var onLift: SkiLapActivityAttributes.ContentState {
        .init(lapCount: 3, lastLapTime: "8分22秒", skiStateText: "乘缆车中 🚡")
    }
}

#Preview("锁屏", as: .content, using: SkiLapActivityAttributes.preview) {
    Lap_Widget_ExtensionLiveActivity()
} contentStates: {
    SkiLapActivityAttributes.ContentState.skiing
    SkiLapActivityAttributes.ContentState.onLift
}
