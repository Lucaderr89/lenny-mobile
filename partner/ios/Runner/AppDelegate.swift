import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Il badge sull'icona lo accende il server: ogni push porta aps.badge = 1.
  // iOS non lo toglie da solo - resta finche' non e' l'app ad azzerarlo, anche
  // dopo che la notifica e' stata letta. Segnarla come letta dentro l'app non
  // c'entra: quello e' un contatore locale, questo e' di sistema, e senza
  // questo azzeramento il "1" restava sull'icona per sempre.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }
}
