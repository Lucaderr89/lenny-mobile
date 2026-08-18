import Flutter
import UIKit
import UserNotifications
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Vedi l'app cliente per il dettaglio: se APNs consegna il device token
    // prima che Firebase sia configurato, firebase_messaging lo parcheggia in
    // una variabile che non rilegge mai e getAPNSToken() resta null per
    // sempre. Configurare qui, prima della registrazione dei plugin, chiude
    // la corsa. Non duplica l'initializeApp fatto da Dart.
    FirebaseApp.configure()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
