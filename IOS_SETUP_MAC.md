# iOS Test Setup — Lenny Apps
> Documento per GitHub Copilot: eseguire questi passi su Mac per portare customer e driver app al primo test iOS.

---

## Pre-requisiti da verificare prima di iniziare

Eseguire questi controlli nella seguente sequenza nel terminale VS Code:

```bash
# 1. Verifica Xcode installato e versione (richiede Xcode 15+)
xcode-select --print-path
xcodebuild -version

# 2. Accettare la licenza Xcode (richiesto la prima volta)
sudo xcodebuild -license accept

# 3. Verifica CocoaPods
pod --version
# Se non installato:
sudo gem install cocoapods

# 4. Verifica Flutter SDK
flutter --version
# Richiede Flutter 3.10.0+ (sdk: ^3.10.0)

# 5. Flutter doctor - deve essere tutto verde eccetto eventualmente Windows/Linux/Web
flutter doctor
```

---

## STEP 1 — App CUSTOMER (`com.lenny.customer`)

```bash
cd mobile/customer

# Scarica le dipendenze Dart e genera il Podfile iOS
flutter pub get

# Installa le dipendenze native iOS tramite CocoaPods
cd ios
pod install --repo-update
cd ..
```

### Verifica dopo pod install
- Deve creare/aggiornare `ios/Podfile.lock`
- Deve creare la cartella `ios/Pods/`
- Non devono esserci errori sui pod `firebase_core`, `firebase_messaging`, `geolocator_apple`, `flutter_inappwebview_ios`

---

## STEP 2 — App DRIVER (`com.lenny.drivers`)

```bash
cd mobile/driver

# Scarica le dipendenze Dart e genera il Podfile iOS
flutter pub get

# Installa le dipendenze native iOS tramite CocoaPods
cd ios
pod install --repo-update
cd ..
```

### Verifica dopo pod install
- Deve creare/aggiornare `ios/Podfile.lock`
- Non devono esserci errori sui pod `firebase_core`, `firebase_messaging`, `geolocator_apple`, `audioplayers_darwin`, `firebase_storage`

---

## STEP 3 — Aprire in Xcode e configurare il Signing

> **IMPORTANTE: aprire sempre il `.xcworkspace`, mai il `.xcodeproj`**

```bash
# Per customer:
open mobile/customer/ios/Runner.xcworkspace

# Per driver:
open mobile/driver/ios/Runner.xcworkspace
```

### In Xcode per ogni app:
1. Seleziona target `Runner` nella sidebar sinistra
2. Tab **Signing & Capabilities**
3. Spunta **Automatically manage signing**
4. In **Team**: seleziona il tuo Apple ID
5. Verifica che il **Bundle Identifier** sia:
   - Customer → `com.lenny.customer`
   - Driver → `com.lenny.drivers`
6. Se appare errore "No profiles found" → clicca **Try Again**

---

## STEP 4 — Collegare il dispositivo iOS e avviare il test

```bash
# Elenca i dispositivi disponibili (fisici + simulatori)
flutter devices

# Avvia customer sul dispositivo fisico (sostituire <device_id> con l'id trovato sopra)
cd mobile/customer
flutter run -d <device_id>

# Avvia driver
cd mobile/driver
flutter run -d <device_id>
```

### Per usare il simulatore iOS:
```bash
# Elenca simulatori disponibili
xcrun simctl list devices available

# Avvia simulatore specifico (es. iPhone 15)
open -a Simulator
flutter run -d "iPhone 15"
```

---

## STEP 5 — Verifica Firebase su iOS

Al primo avvio verificare nella console Firebase:
1. Aprire [Firebase Console](https://console.firebase.google.com) → progetto `lennyv2-7d4c4`
2. Tab **Project Overview** → sezione app iOS
3. Verificare che appaia `com.lenny.customer` e `com.lenny.drivers`
4. In **Messaging** → mandare un messaggio di test al device token che apparirà nei log

---

## STEP 6 — Test permessi iOS (da fare a mano sul device)

Avviare le app e verificare che iOS mostri i dialog di autorizzazione per:

### Customer:
- [ ] Posizione ("Quando in uso") → accettare
- [ ] Notifiche push → accettare
- [ ] Fotocamera (al primo accesso al profilo) → accettare
- [ ] Libreria foto (al primo accesso al profilo) → accettare

### Driver:
- [ ] Posizione ("Sempre") → accettare — **critico per il tracking consegne**
- [ ] Notifiche push → accettare
- [ ] Audio in background → verificare che gli alert sonori arrivino anche a schermo spento
- [ ] Fotocamera → accettare
- [ ] Libreria foto → accettare

---

## Problemi comuni e soluzioni

### Errore: `CocoaPods not found`
```bash
sudo gem install cocoapods
pod setup
```

### Errore: `pod install` fallisce su Firebase
```bash
cd ios
pod repo update
pod install
```

### Errore: `Swift package manager` conflict
Il progetto usa CocoaPods classico (`swift_package_manager_enabled: false`).
Se Xcode propone di migrare a SPM → **rifiutare**.

### Errore: `No such module 'Firebase'`
```bash
cd ios
pod deintegrate
pod install
```
Poi chiudere e riaprire il `.xcworkspace`.

### Errore signing: `Provisioning profile ... doesn't include the aps-environment entitlement`
Per le push notification su device fisico serve un profilo con **Push Notifications capability**.
In Xcode → Signing & Capabilities → `+` → aggiungere **Push Notifications**.

### Build fallisce con errore `DT_TOOLCHAIN_DIR`
```bash
cd ios
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
pod install
```

### `flutter run` non vede il device fisico
- Verificare che il device abbia **Modalità sviluppatore** attiva (Impostazioni → Privacy → Modalità sviluppatore)
- Su iOS 16+: Impostazioni → Privacy e sicurezza → Modalità sviluppatore → ON

---

## File chiave già configurati (non toccare)

| File | Stato |
|---|---|
| `customer/ios/Runner/GoogleService-Info.plist` | ✅ Presente, Bundle ID: `com.lenny.customer` |
| `driver/ios/Runner/GoogleService-Info.plist` | ✅ Presente, Bundle ID: `com.lenny.drivers` |
| `customer/ios/Runner/Info.plist` | ✅ Permessi Privacy + UIBackgroundModes configurati |
| `driver/ios/Runner/Info.plist` | ✅ Permessi Privacy + UIBackgroundModes (location, audio, remote-notification) configurati |
| `customer/android/app/google-services.json` | ✅ (Android, non modificare) |
| `driver/android/app/google-services.json` | ✅ (Android, non modificare) |

---

## Note finali

- L'app **partner** non viene compilata per iOS (usa `sunmi_printer_plus` che è Android-only) — ignorare.
- Per il test su **simulatore**: la geolocalizzazione e le push notification hanno limitazioni; usare device fisico per test completi.
- Il progetto usa **Flutter 3.10+** — verificare con `flutter --version` che la versione sul Mac sia compatibile.
