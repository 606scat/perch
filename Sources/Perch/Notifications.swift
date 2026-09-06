import Foundation
import UserNotifications
import PerchCore

@MainActor final class FocusNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var generation = 0
    private var scheduling: Task<Void, Never>?
    var errorHandler: ((String) -> Void)?
    override init() { super.init(); center.delegate = self }
    func requestAccess() async -> Bool {
        do { return try await center.requestAuthorization(options: [.alert, .sound]) }
        catch { errorHandler?("Couldn’t enable focus alerts: \(error.localizedDescription)"); return false }
    }
    func update(_ focus: FocusSession?, sound: Bool) {
        generation += 1
        let current = generation
        let previous = scheduling
        scheduling = Task {
            await previous?.value
            guard current == generation else { return }
            center.removePendingNotificationRequests(withIdentifiers: ["perch-focus"])
            guard let focus, let end = focus.endsAt, end > Date() else { return }
            let settings = await center.notificationSettings()
            guard current == generation, settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Focus complete"; content.body = focus.title
            if sound { content.sound = UNNotificationSound(named: .init("finish.wav")) }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
            do {
                try await center.add(.init(identifier: "perch-focus", content: content, trigger: trigger))
            } catch { errorHandler?("Couldn’t schedule the focus alert: \(error.localizedDescription)") }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The running app plays the authored chime; avoid playing a second sound over it.
        completionHandler([.banner, .list])
    }
}
