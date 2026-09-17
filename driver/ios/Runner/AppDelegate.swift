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

    // Badge dell'icona: si azzera OGNI volta che l'app torna in primo piano.
    // Con il ciclo di vita "a scene" (UIApplicationSceneManifest nel
    // Info.plist) iOS NON chiama piu' applicationDidBecomeActive sull'app
    // delegate, e l'azzeramento che stava li' non girava mai (visto
    // sull'iPhone il 17/09/2026). Le notifiche di sistema qui sotto arrivano
    // in tutti e due i cicli di vita.
    let centro = NotificationCenter.default
    centro.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
      AppDelegate.azzeraBadge()
    }
    if #available(iOS 13.0, *) {
      centro.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
        AppDelegate.azzeraBadge()
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // La finestra dell'app, anche con il ciclo di vita "a scene": con il
  // manifest a scene `UIApplication.shared.delegate?.window` e' nil, e i
  // plugin che presentano schermate native da li' (foglio di Stripe nell'app
  // cliente, in futuro il lettore Tap to Pay qui) finirebbero su un controller
  // fantasma. Stessa correzione dell'app cliente.
  override var window: UIWindow? {
    get {
      if let w = super.window {
        return w
      }
      let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }
    set {
      super.window = newValue
    }
  }

  // Il badge sull'icona lo accende il server: ogni push porta aps.badge = 1.
  // iOS non lo toglie da solo - resta finche' non e' l'app ad azzerarlo, anche
  // dopo che la notifica e' stata letta. Segnarla come letta dentro l'app non
  // c'entra: quello e' un contatore locale, questo e' di sistema.
  static func azzeraBadge() {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
  }

  // Tenuto per il ciclo di vita senza scene (se un giorno il manifest sparisse).
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    AppDelegate.azzeraBadge()
  }
}
