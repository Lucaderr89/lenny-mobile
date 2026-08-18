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
    // Firebase va configurato QUI, prima che i plugin si registrino.
    //
    // Appena si registra, firebase_messaging chiama registerForRemoteNotifications.
    // Se APNs risponde prima che Firebase esista - e succede, perche' iOS tiene
    // in cache il device token e lo riconsegna quasi subito - il plugin finisce
    // in questo ramo:
    //
    //     if ([FIRMessaging messaging] == nil) { _apnsToken = deviceToken; }
    //     [[FIRMessaging messaging] setAPNSToken:...];   // messaggio a nil: no-op
    //
    // Il token resta parcheggiato in una variabile che nessuno rilegge mai:
    // getAPNSToken() torna null per sempre e getToken() fallisce con
    // apns-token-not-set. Configurando qui, FIRMessaging esiste gia' quando la
    // callback arriva.
    //
    // Non duplica l'inizializzazione fatta da Dart in main(): firebase_core
    // riusa l'app di default se la trova gia' configurata.
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
