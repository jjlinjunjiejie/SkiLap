
//  SkiLapApp.swift
//  SkiLap
//
//  App 入口：配置通知代理，确保 App 在前台运行时也能弹出通知
//

import SwiftUI
import UserNotifications

@main
struct SkiLapApp: App {
    // 注入 AppDelegate 以设置通知代理
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 将自身设为通知中心代理，使 App 在前台时也能展示横幅通知
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // App 处于前台时，仍展示横幅 + 声音通知（否则计圈通知会被静默丢弃）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
