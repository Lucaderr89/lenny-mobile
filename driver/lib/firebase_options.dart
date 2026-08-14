// File generato per il progetto Firebase LennyV2 (lennyv2-7d4c4)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        // Niente app macOS registrata su Firebase: il blocco "macos" che
        // stava qui era una copia dell'appId Android spacciata per iOS, e
        // avrebbe fallito a runtime in modo incomprensibile. Meglio un
        // errore che dice la verita'.
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDAVd_RXhjLsx1hoZLB7ZYvqjsGynS0tBE',
    appId: '1:215648872015:android:2c33491b1614cb3d3a6c3a',
    messagingSenderId: '215648872015',
    projectId: 'lennyv2-7d4c4',
    storageBucket: 'lennyv2-7d4c4.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAPwGh6c-aq3J7oVCNEeFcbM2fim35k5Dg',
    appId: '1:215648872015:web:b66d02abe5108cd23a6c3a',
    messagingSenderId: '215648872015',
    projectId: 'lennyv2-7d4c4',
    authDomain: 'lennyv2-7d4c4.firebaseapp.com',
    storageBucket: 'lennyv2-7d4c4.firebasestorage.app',
    measurementId: 'G-3MCCC4L6R9',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsKWXEv7ezWykDS0ZcuAfAmmrEU9-VZL4',
    appId: '1:215648872015:ios:ab14cd40cd4a45eb3a6c3a',
    messagingSenderId: '215648872015',
    projectId: 'lennyv2-7d4c4',
    storageBucket: 'lennyv2-7d4c4.firebasestorage.app',
    iosBundleId: 'com.lenny.drivers',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAPwGh6c-aq3J7oVCNEeFcbM2fim35k5Dg',
    appId: '1:215648872015:web:b66d02abe5108cd23a6c3a',
    messagingSenderId: '215648872015',
    projectId: 'lennyv2-7d4c4',
    storageBucket: 'lennyv2-7d4c4.firebasestorage.app',
  );
}
