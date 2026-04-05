
//  ContentView.swift
//  SkiLap
//

import SwiftUI

struct ContentView: View {
    @State private var tracker = SkiLapTracker()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // 状态卡片（紧凑）
                        StateCardView(tracker: tracker)
                            .padding(.horizontal)

                        // 上一圈大字展示
                        LastLapBannerView(record: tracker.lapRecords.last)
                            .padding(.horizontal)

                        // 每圈时间列表（倒序）
                        if !tracker.lapRecords.isEmpty {
                            LapTimeListView(records: tracker.lapRecords)
                                .padding(.horizontal)
                        }

                        // 底部留白（为悬浮按钮）
                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 8)
                }
            }
            .overlay(alignment: .bottom) {
                ControlButton(tracker: tracker)
                    .padding(.horizontal)
                    .padding(.bottom, 28)
            }
            .navigationTitle("SkiLap 计圈")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 状态卡片（紧凑版）
struct StateCardView: View {
    var tracker: SkiLapTracker

    var body: some View {
        HStack(spacing: 16) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: tracker.state.systemIcon)
                    .font(.system(size: 24))
                    .foregroundColor(stateColor)
            }
            .animation(.easeInOut(duration: 0.3), value: tracker.state)

            VStack(alignment: .leading, spacing: 4) {
                Text(tracker.state.rawValue)
                    .font(.headline)
                    .foregroundColor(stateColor)
                HStack(spacing: 4) {
                    Image(systemName: "mountain.2.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "气压海拔 %.0f 米", tracker.pressureAltitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            // 圈数徽章
            if !tracker.lapRecords.isEmpty {
                VStack(spacing: 2) {
                    Text("\(tracker.lapRecords.count)")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(stateColor)
                    Text("圈")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }

    private var stateColor: Color {
        switch tracker.state {
        case .idle:              return .gray
        case .skiingAndQueueing: return .blue
        case .onLift:            return .orange
        }
    }
}

// MARK: - 上一圈大字展示
struct LastLapBannerView: View {
    let record: LapRecord?

    var body: some View {
        VStack(spacing: 8) {
            Text("上一圈时间")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let r = record {
                Text(r.formattedDuration)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: r.lapNumber)
            } else {
                Text("— — 分 — — 秒")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }
}

// MARK: - 每圈时间列表（倒序）
struct LapTimeListView: View {
    let records: [LapRecord]

    private var averageDuration: TimeInterval {
        records.map { $0.duration }.reduce(0, +) / Double(records.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 平均圈速标题行
            HStack {
                Text("历史圈速")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                let m = Int(averageDuration) / 60
                let s = Int(averageDuration) % 60
                Text("均速 \(m)分\(String(format: "%02d", s))秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))

            Divider().padding(.horizontal, 16)

            // 倒序圈速列表
            LazyVStack(spacing: 0) {
                ForEach(records.reversed()) { record in
                    LapTimeRow(
                        record: record,
                        isLatest: record.lapNumber == records.count
                    )
                    if record.lapNumber != 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - 单行圈速
struct LapTimeRow: View {
    let record: LapRecord
    let isLatest: Bool

    var body: some View {
        HStack {
            // 圈数
            Text("第 \(record.lapNumber) 圈")
                .font(.subheadline)
                .foregroundColor(isLatest ? .blue : .secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            // 时间（大字）
            Text(record.formattedDuration)
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(isLatest ? .primary : .secondary)
                .monospacedDigit()

            // 最新圈标签
            if isLatest {
                Text("最新")
                    .font(.caption2).fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue))
                    .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isLatest ? Color.blue.opacity(0.04) : Color.clear)
    }
}

// MARK: - 控制按钮
struct ControlButton: View {
    var tracker: SkiLapTracker

    var body: some View {
        Button {
            Task {
                if tracker.isTracking {
                    await tracker.stopTracking()
                } else {
                    await tracker.startTracking()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tracker.isTracking ? "stop.fill" : "play.fill")
                    .font(.title3)
                Text(tracker.isTracking ? "停止追踪" : "开始追踪")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(tracker.isTracking ? Color.red : Color.blue)
                    .shadow(color: (tracker.isTracking ? Color.red : Color.blue).opacity(0.4),
                            radius: 10, y: 5)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: tracker.isTracking)
    }
}

#Preview {
    ContentView()
}
