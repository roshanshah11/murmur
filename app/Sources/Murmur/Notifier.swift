import Foundation
import UserNotifications

enum Notifier {
    private static var authorized = false
    private static var requested = false

    static func bootstrap() {
        guard !requested else { return }
        requested = true
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            authorized = granted
            Log.event(state: "notifier_authorization", fields: ["granted": String(granted)])
        }
    }

    static func success(_ message: String) {
        post(title: "Murmur", body: message)
    }

    static func warn(_ message: String) {
        post(title: "Murmur", body: message)
    }

    private static func post(title: String, body: String) {
        // Always log; banners are best-effort and only work in a signed .app bundle.
        Log.event(state: "notify", fields: ["title": title, "body": body])

        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { _ in }
    }
}
