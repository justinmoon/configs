import AppKit
import UserNotifications

func printHelp() {
    print("""
    OpenCodeNotifier - macOS notification agent for OpenCode

    USAGE:
        opencode-notify --title "Title" --message "Message" [--sound SOUND]

    OPTIONS:
        -t, --title TITLE     Notification title
        -m, --message MSG     Notification body
        -s, --sound SOUND     Sound name (default: Glass)
        -h, --help            Show help

    SOUNDS:
        Glass (default), Basso, Blow, Bottle, Frog, Funk, 
        Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
    """)
}

if CommandLine.arguments.contains("-h") || CommandLine.arguments.contains("--help") {
    printHelp()
    exit(0)
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var title = "OpenCode"
    var message = "Notification"
    var soundName = "Glass"

    override init() {
        super.init()
        let args = CommandLine.arguments
        for i in 0..<args.count {
            if (args[i] == "-t" || args[i] == "--title") && i + 1 < args.count {
                title = args[i + 1]
            }
            if (args[i] == "-m" || args[i] == "--message") && i + 1 < args.count {
                message = args[i + 1]
            }
            if (args[i] == "-s" || args[i] == "--sound") && i + 1 < args.count {
                soundName = args[i + 1]
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.sendNotification()
                } else if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        if granted { 
                            DispatchQueue.main.async { self.sendNotification() } 
                        } else { 
                            NSApp.terminate(nil) 
                        }
                    }
                } else {
                    print("Error: Notifications disabled. Enable in System Settings > Notifications > OpenCodeNotifier")
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.interruptionLevel = .timeSensitive

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error sending notification: \(error)")
                }
                NSSound(named: NSSound.Name(self.soundName))?.play()
                // Exit after a short delay to ensure notification is delivered
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { 
                    NSApp.terminate(nil) 
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        handler()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
