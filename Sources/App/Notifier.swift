import AppKit
import UserNotifications

/// MacOS notifications for finished downloads. Silent when the app is in front or run without a bundle.
@MainActor
enum Notifier {
    static func requestAuthorizationIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        // The center is fetched again inside the callback, which runs off the main actor.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    static func jobFinished(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil,
              !NSApplication.shared.isActive,
              SettingsStore.shared.notifyWhenDone
        else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
