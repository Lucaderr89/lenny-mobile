import Flutter
import UIKit
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
}
