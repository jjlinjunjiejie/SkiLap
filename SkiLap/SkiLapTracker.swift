
//  SkiLapTracker.swift
//  SkiLap
//
//  核心追踪类：使用气压计自动识别缆车状态并计算单圈时间
//
//  【单圈时间定义】
//  单圈时间 = 乘坐缆车时间 + 滑降时间 + 谷底排队等待时间
//  实现方式：记录【两次坐上缆车瞬间的谷底时间差】即为单圈时间
//

import Foundation
import CoreMotion
import UserNotifications
import ActivityKit
import Observation
import HealthKit

// MARK: - 状态机枚举
enum SkiState: String, Equatable {
    case idle               = "待机"
    case skiingAndQueueing  = "滑行 / 排队中"
    case onLift             = "乘坐缆车中"

    var systemIcon: String {
        switch self {
        case .idle:              return "snowflake"
        case .skiingAndQueueing: return "figure.snowboarding"
        case .onLift:            return "tram.fill"
        }
    }
}

// MARK: - 单圈记录
struct LapRecord: Identifiable {
    let id = UUID()
    let lapNumber: Int
    let duration: TimeInterval    // 秒
    let completedAt: Date         // 本圈谷底时间（即本次坐缆车时刻）

    /// 格式化显示，如 "5分32秒"
    var formattedDuration: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d分%02d秒", m, s)
    }
}

// MARK: - SkiLapTracker
@MainActor
@Observable
final class SkiLapTracker: NSObject {

    // MARK: 可观测属性（供 SwiftUI 视图绑定，使用 @Observable 宏，无需 Combine）
    private(set) var state: SkiState = .idle
    private(set) var currentAltitude: Double = 0.0   // 平滑后的相对海拔（米，内部算法用）
    /// 气压海拔（米）：由实时气压值通过国际标准大气公式换算，用于界面显示
    private(set) var pressureAltitude: Double = 0.0
    private(set) var lapRecords: [LapRecord] = []
    private(set) var isTracking: Bool = false
    private(set) var statusMessage: String = "按下开始按钮开始记录"

    // MARK: 核心状态变量
    /// 当前循环中追踪到的局部最低海拔（谷底）
    private var localMinAltitude: Double = 0.0
    /// 达到局部最低海拔的时间戳（即即将坐上缆车的那一刻）
    private var timeAtLocalMin: Date = Date()
    /// 上一次坐上缆车时的谷底时间戳
    /// ====================================================
    /// 【关键逻辑】两次谷底时间差 = 单圈时间
    ///   本圈时间 = timeAtLocalMin(本次) - lastLiftStartTime(上次)
    ///   包含：本次缆车上升 + 滑降 + 谷底排队等待
    /// ====================================================
    private var lastLiftStartTime: Date? = nil

    // MARK: 气压计
    private let altimeter = CMAltimeter()
    /// 专用后台队列：确保锁屏后气压计回调不受主线程挂起影响
    private let altimeterQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.skilap.altimeter"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()
    /// 启动时记录的基准海拔（用于将绝对值转为相对值）
    private var baselineAltitude: Double? = nil
    /// EMA 平滑系数（0~1）：越小越平滑，越大越灵敏
    private let smoothAlpha: Double = 0.15
    private var smoothedAltitude: Double = 0.0

    // MARK: 山顶检测
    /// 异步山顶检测任务
    private var summitTask: Task<Void, Never>? = nil
    /// 滑动窗口内的海拔历史记录（时间 + 海拔）
    private var altitudeHistory: [(time: Date, altitude: Double)] = []
    /// 山顶判定：需要海拔稳定的时间窗口（秒）
    private let summitWindow: TimeInterval = 10.0
    /// 山顶判定：窗口内最大波动容差（米）
    private let summitStabilityThreshold: Double = 2.0

    // MARK: 阈值
    /// 判定坐上缆车的最低海拔上升量（超过谷底多少米）
    private let liftThreshold: Double = 15.0

    // MARK: Live Activity
    private var liveActivity: Activity<SkiLapActivityAttributes>? = nil


    // MARK: HealthKit 后台保活
    private let healthStore = HKHealthStore()
    /// HKWorkoutSession（iOS 17+）：开启后系统赋予最高后台优先级，确保气压计锁屏持续运行
    private var workoutSession: HKWorkoutSession?

    // MARK: - 启动追踪
    func startTracking() async {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            statusMessage = "❌ 此设备不支持气压计（相对海拔）"
            return
        }

        // 申请通知权限
        await requestNotificationPermission()

        // 重置全部状态
        resetState()
        isTracking = true
        state = .skiingAndQueueing
        statusMessage = "正在追踪，等待首次下坡..."

        // 启动 HealthKit 体能训练会话（后台保活：锁屏后气压计持续运行）
        await startWorkoutSession()

        // 启动实时活动（锁屏显示 + 灵动岛）
        await startLiveActivity()

        // 订阅气压计：在专用后台队列接收数据（锁屏后主线程会被挂起，后台队列不会）
        altimeter.startRelativeAltitudeUpdates(to: altimeterQueue) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            // 后台队列收到数据后，切回 MainActor 驱动状态机和 UI 更新
            Task { @MainActor [weak self] in
                self?.processAltimeterData(data)
            }
        }
    }

    // MARK: - 停止追踪
    func stopTracking() async {
        altimeter.stopRelativeAltitudeUpdates()
        summitTask?.cancel()
        summitTask = nil
        isTracking = false
        state = .idle
        statusMessage = "追踪已停止，共完成 \(lapRecords.count) 圈"
        // 结束体能训练会话（不保存任何健康数据）
        stopWorkoutSession()
        await endLiveActivity()
    }

    // MARK: - 内部重置
    private func resetState() {
        baselineAltitude = nil
        smoothedAltitude = 0.0
        currentAltitude = 0.0
        localMinAltitude = 0.0
        timeAtLocalMin = Date()
        lastLiftStartTime = nil
        lapRecords = []
        altitudeHistory = []
    }

    // MARK: - 气压计数据处理（核心入口）
    private func processAltimeterData(_ data: CMAltitudeData) {
        let rawRelative = data.relativeAltitude.doubleValue

        // 由实时气压（kPa）换算气压海拔（米）
        // 国际标准大气公式：h = 44330 × (1 - (P/P₀)^(1/5.255))
        // P₀ = 1013.25 hPa = 101.325 kPa（标准海平面气压）
        let pressureKPa = data.pressure.doubleValue
        pressureAltitude = 44330.0 * (1.0 - pow(pressureKPa / 101.325, 1.0 / 5.255))

        // 首次读取：设定基准，初始化所有谷底记录
        if baselineAltitude == nil {
            baselineAltitude = rawRelative
            smoothedAltitude = 0.0
            localMinAltitude = 0.0
            timeAtLocalMin = Date()
            return
        }

        // 计算相对于启动时的海拔差（内部算法仍用相对海拔驱动状态机）
        let relative = rawRelative - (baselineAltitude ?? rawRelative)

        // EMA 平滑滤波：减少气压计高频噪声
        //   新平滑值 = α × 原始值 + (1-α) × 上次平滑值
        smoothedAltitude = smoothAlpha * relative + (1 - smoothAlpha) * smoothedAltitude
        currentAltitude = smoothedAltitude

        // 记录到历史（用于山顶检测的滑动窗口分析）
        let now = Date()
        altitudeHistory.append((time: now, altitude: smoothedAltitude))
        // 只保留最近 (summitWindow + 5) 秒的数据
        let cutoff = now.addingTimeInterval(-(summitWindow + 5))
        altitudeHistory.removeAll { $0.time < cutoff }

        // 驱动状态机
        switch state {
        case .idle:
            break
        case .skiingAndQueueing:
            applyRuleA()   // 规则 A：寻找谷底，检测上缆车
        case .onLift:
            break          // 规则 B：由 summitTask 异步完成
        }
    }

    // MARK: - 规则 A：谷底追踪 + 上缆车检测
    ///
    /// 在滑行/排队阶段，持续追踪海拔最低点（谷底）。
    /// 当海拔从谷底显著上升（> liftThreshold 米）时，
    /// 判定用户已坐上缆车，触发计圈逻辑。
    ///
    private func applyRuleA() {
        // 持续更新谷底：只要当前海拔 ≤ 已知谷底，就覆写
        if currentAltitude <= localMinAltitude {
            localMinAltitude = currentAltitude
            timeAtLocalMin = Date()
        }

        // 上缆车判断：当前海拔 超过谷底 liftThreshold 米
        guard currentAltitude > localMinAltitude + liftThreshold else { return }

        // ============================================================
        // 【触发计圈】
        //
        // 两次谷底时间差 = 单圈时间（完整循环）：
        //   圈时间 = timeAtLocalMin（本次谷底）- lastLiftStartTime（上次谷底）
        //         = 乘缆车时间 + 滑降时间 + 谷底排队时间
        // ============================================================
        if let prevStart = lastLiftStartTime {
            let lapDuration = timeAtLocalMin.timeIntervalSince(prevStart)
            let lapNum = lapRecords.count + 1
            let record = LapRecord(
                lapNumber: lapNum,
                duration: lapDuration,
                completedAt: timeAtLocalMin
            )
            lapRecords.append(record)

            Task {
                await sendLapNotification(record: record)
                await updateLiveActivity(with: record)
            }

            statusMessage = "第\(lapNum)圈：\(record.formattedDuration)"
        }

        // 【关键更新】将本次谷底时间记为下一圈的起点
        lastLiftStartTime = timeAtLocalMin

        // 切换状态：开始上缆车
        state = .onLift
        Task { await updateLiveActivityState("乘缆车中 🚡") }

        // 启动异步山顶检测任务
        startSummitDetection()
    }

    // MARK: - 规则 B：山顶检测（异步滑动窗口分析）
    ///
    /// 在乘坐缆车阶段，每 2 秒分析最近 summitWindow 秒内的海拔历史。
    /// 若窗口内海拔波动 < summitStabilityThreshold 米，判定到达山顶。
    ///
    private func startSummitDetection() {
        summitTask?.cancel()
        summitTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.checkForSummit() }
            }
        }
    }

    private func checkForSummit() {
        guard state == .onLift else {
            summitTask?.cancel()
            return
        }

        let now = Date()
        let windowData = altitudeHistory.filter { $0.time >= now.addingTimeInterval(-summitWindow) }
        guard windowData.count >= 4 else { return }  // 数据点不足，继续等待

        let altitudes = windowData.map { $0.altitude }
        let range = altitudes.max()! - altitudes.min()!

        // 条件一：窗口内波动小
        guard range < summitStabilityThreshold else { return }

        // 条件二：没有明显的持续上升趋势（防止在缆车中途误判）
        let firstAlt = windowData.first!.altitude
        let lastAlt  = windowData.last!.altitude
        guard (lastAlt - firstAlt) < 5.0 else { return }

        // ✅ 山顶判定成功
        onSummitDetected()
    }

    private func onSummitDetected() {
        summitTask?.cancel()
        summitTask = nil

        state = .skiingAndQueueing
        statusMessage = "✅ 已到达山顶，开始滑行！"

        // 将谷底基准重置为当前山顶海拔，准备追踪下一次谷底
        localMinAltitude = currentAltitude
        timeAtLocalMin = Date()

        Task { await updateLiveActivityState("滑行中 🎿") }
    }

    // MARK: - HealthKit 体能训练会话（后台保活核心）

    /// 开启滑雪体能训练会话。
    /// iOS 17+ 中，活跃的 HKWorkoutSession 可让 App 在锁屏后持续在后台运行，
    /// 等同于 Apple Watch 的 Workout 后台权限，是保证气压计数据不中断的最可靠手段。
    private func startWorkoutSession() async {
        guard #available(iOS 17.0, *),
              HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HKWorkoutSession 不可用（需 iOS 17+ 且设备支持 HealthKit）")
            return
        }

        // 申请 HealthKit 写权限（仅用于开启会话，不实际写入数据）
        let workoutType = HKQuantityType.workoutType()
        do {
            try await healthStore.requestAuthorization(toShare: [workoutType], read: [])
        } catch {
            print("⚠️ HealthKit 授权失败: \(error)")
            return
        }

        // 配置：单板滑雪户外运动
        let config = HKWorkoutConfiguration()
        config.activityType = .snowboarding
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            workoutSession = session
            session.startActivity(with: .now)
            print("✅ 体能训练会话已启动，锁屏后气压计将持续运行")
        } catch {
            print("❌ 体能训练会话启动失败: \(error)")
        }
    }

    /// 结束会话，不调用 finishWorkout()，因此不向「健康」App 写入任何记录。
    private func stopWorkoutSession() {
        guard #available(iOS 17.0, *) else { return }
        workoutSession?.stopActivity(with: .now)
        workoutSession?.end()
        workoutSession = nil
        print("✅ 体能训练会话已结束（未写入健康数据）")
    }

    // MARK: - 本地通知
    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print(granted ? "✅ 通知权限已授权" : "⚠️ 通知权限被拒绝")
        } catch {
            print("通知授权失败: \(error)")
        }
    }

    private func sendLapNotification(record: LapRecord) async {
        let content = UNMutableNotificationContent()
        content.title = ""
        content.body = "第\(record.lapNumber)圈：\(record.formattedDuration)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive  // 计时敏感，确保通知弹出

        let request = UNNotificationRequest(
            identifier: "ski_lap_\(record.lapNumber)",
            content: content,
            trigger: nil  // 立即发送
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("通知发送失败: \(error)")
        }
    }

    // MARK: - 实时活动（Live Activity）
    private func startLiveActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ 实时活动未启用（请在系统设置中开启）")
            return
        }

        let attributes = SkiLapActivityAttributes()
        let initialState = SkiLapActivityAttributes.ContentState(
            lapCount: 0,
            lastLapTime: nil,
            skiStateText: "滑行中 🎿"
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            print("✅ 实时活动已启动，ID: \(liveActivity?.id ?? "unknown")")
        } catch {
            print("❌ 实时活动启动失败: \(error)")
        }
    }

    private func updateLiveActivity(with record: LapRecord) async {
        let newState = SkiLapActivityAttributes.ContentState(
            lapCount: record.lapNumber,
            lastLapTime: record.formattedDuration,
            skiStateText: "乘缆车中 🚡"
        )
        await liveActivity?.update(.init(state: newState, staleDate: nil))
    }

    private func updateLiveActivityState(_ stateText: String) async {
        let newState = SkiLapActivityAttributes.ContentState(
            lapCount: lapRecords.count,
            lastLapTime: lapRecords.last?.formattedDuration,
            skiStateText: stateText
        )
        await liveActivity?.update(.init(state: newState, staleDate: nil))
    }

    private func endLiveActivity() async {
        let finalState = SkiLapActivityAttributes.ContentState(
            lapCount: lapRecords.count,
            lastLapTime: lapRecords.last?.formattedDuration,
            skiStateText: "追踪已结束"
        )
        await liveActivity?.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .default
        )
        liveActivity = nil
    }
}

// MARK: - HKWorkoutSessionDelegate
extension SkiLapTracker: HKWorkoutSessionDelegate {
    /// 会话状态变化回调（running / stopped / ended 等）
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("体能训练会话状态: \(fromState.rawValue) → \(toState.rawValue)")
    }

    /// 会话发生错误时回调
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("体能训练会话错误: \(error.localizedDescription)")
    }
}
