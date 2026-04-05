
//  SkiLapActivityAttributes.swift
//  SkiLap
//
//  实时活动（Live Activity）属性定义
//  ⚠️ 重要：此文件需同时加入主 App Target 与 Widget Extension Target 的 Target Membership
//

import ActivityKit
import Foundation

// MARK: - 实时活动属性（主 App 与 Widget Extension 共用）
struct SkiLapActivityAttributes: ActivityAttributes {

    // MARK: 动态状态（可在运动过程中随时更新）
    struct ContentState: Codable, Hashable {
        /// 已完成的圈数
        var lapCount: Int
        /// 最近一圈的格式化时长，例如 "5分32秒"
        var lastLapTime: String?
        /// 当前状态文字：滑行中 / 乘缆车中 / 已结束
        var skiStateText: String
    }

    // 无需静态属性（会话启动时所有数据均通过 ContentState 传递）
}
