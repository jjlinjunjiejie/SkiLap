# 🏂 SkiLap - 自动滑雪计圈追踪器 (Auto Ski Lap Tracker)

SkiLap 是一款专为硬核滑雪者设计的 iOS 原生应用。它利用 iPhone 内置的气压高度计（Barometer），在无需网络和持续高频 GPS 的情况下，自动且精准地识别您的滑雪状态（上缆车、滑降、排队）。本代码使用Xcode内置Claude Vibe Coding生成。

与其他将“单圈”定义为“纯滑降时间”的常规软件不同，SkiLap 专注于**“大循环时间”**——即包含乘坐缆车、滑降以及谷底排队等候的完整周期时间。这帮助滑雪者更科学地规划体能，并精准预估下一趟“刷圈”所需的时间。

## ✨ 核心特性

* **🦅 气压计级精准触发**：利用 `CoreMotion` 气压计感知极微弱的海拔变化，比纯 GPS 定位反应更敏锐、更省电。兼容所有运行速度的缆车（吊厢、拖牵、吊椅）。
* **🔄 全新“单圈”定义**：单圈时间 = `乘坐缆车时间 + 滑降时间 + 排队等候时间`。自动寻找两次“谷底”的时间差，容错率极高。
* **🏝️ 灵动岛与实时活动 (Live Activities)**：支持锁屏实时活动与灵动岛展示，无需解锁手机即可随时查看当前滑到了第几圈以及上一圈的耗时。
* **🔋 后台完美保活**：深度接入苹果 `HealthKit` 体能训练会话，辅以低频位置更新，突破 iOS 锁屏休眠限制，确保手机放在口袋里依然能分秒不差地稳定计圈。

## 🧠 核心算法原理

应用底层基于**“趋势与谷底触发（Trough-to-Peak）”**状态机算法：
1. **寻找谷底**：在用户滑降和排队时，系统持续追踪局部最低海拔（T_start）。
2. **判定上缆车**：当当前气压海拔比“局部最低点”持续升高超过 **15米** 时，系统判定用户已坐上缆车。
3. **计圈推送**：此时系统将触发本地通知和灵动岛更新，并计算当前时间与上一次谷底时间（上一次坐上缆车）的差值，作为一整圈的耗时。
4. **到达山顶**：当海拔停止上升并保持平稳时，系统重置谷底基准线，准备捕捉下一次循环。

## 🛠️ 技术栈

* **语言**: Swift 5+
* **UI 框架**: SwiftUI
* **核心框架**: 
    * `CoreMotion` (`CMAltimeter`) - 核心气压数据源
    * `HealthKit` (`HKWorkoutSession`) - 后台保活与运动状态管理
    * `ActivityKit` - 灵动岛与锁屏小组件界面
    * `CoreLocation` - 辅助后台保活
    * `UserNotifications` - 计圈本地推送

## ⚙️ 编译与运行配置 (开发者必读)

为了让应用能在真机上顺利运行并突破后台限制，请在克隆代码后，务必在 Xcode 中完成以下配置：

### 1. 签名与能力 (Signing & Capabilities)
在 Xcode 中选中主 Target (`SkiLaps`)：
* 配置您的个人开发者团队 (Team)。
* 添加 **HealthKit** 能力。
* 添加 **Background Modes** 能力，并务必勾选：
    * `Location updates`
    * `Workout processing`

对于 Widget Target (`Lap-Widget-Extension`)：
* 同样配置您的个人开发者团队 (Team)。
* 确保其 Bundle Identifier 为主应用的子集。

### 2. Info.plist 隐私权限说明
请确保主应用 Info.plist 文件中包含以下键值对，否则会在启动时触发系统保护性闪退：
* `NSMotionUsageDescription`: "SkiLaps 需要使用您的运动与气压计数据来自动识别缆车并记录滑雪圈数。"
* `NSHealthShareUsageDescription`: "SkiLaps 需要读取您的体能训练数据，以识别您的滑雪状态。"
* `NSHealthUpdateUsageDescription`: "SkiLaps 需要写入体能训练数据，以便在后台持续为您记录滑雪圈数。"
* `NSLocationWhenInUseUsageDescription`: "SkiLaps 需要在后台持续记录以防被系统休眠。"
* `NSSupportsLiveActivities`: YES (Boolean)

## 📱 运行环境要求

* **设备**: 必须配备气压计的 iPhone 真机（模拟器无法模拟气压和灵动岛后台流转）。
* **系统**: iOS 16.1+ (灵动岛支持要求)。
* 在首次真机运行时，请确保在 iPhone 的“设置 -> 隐私与安全性”中开启**开发者模式**。

---
*Developed with pure passion for skiing.* ⛷️❄️
