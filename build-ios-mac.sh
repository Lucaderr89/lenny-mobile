#!/bin/zsh
# Compila, firma e impacchetta una .ipa di Lenny per App Store Connect.
# Gira SUL MAC. Gemello di prova-iphone-mac.sh, che installa sul telefono:
# questo invece produce il pacchetto da caricare sullo store.
#
# Uso (dalla sessione Windows, via SSH):
#
#   ssh -i ~/.ssh/id_ed25519_mac titanodevstudio@192.168.1.110 \
#     'cd /Applications/MAMP/htdocs/lenny-mobile && zsh build-ios-mac.sh customer'
#
# L'argomento e' customer oppure driver (l'app partner su iOS non esiste).
# Secondo argomento facoltativo:
#   esporta -> salta compilazione e archivio, riparte dall'archivio gia' fatto
#              (serve quando l'esportazione cade per rete e l'archivio e' buono)
#
# IL CARICAMENTO SU APP STORE CONNECT NON E' QUI DI PROPOSITO: e' un'azione
# verso l'esterno e si lancia a mano, quando si e' deciso di caricare:
#
#   xcrun altool --upload-app -f "<file.ipa>" -t ios \
#     --apiKey ZSR6KF48RK --apiIssuer ed3ff578-1aa7-46bf-a803-f1a393afa2fb
#
# PERCHE' LA SESSIONE GRAFICA: una sessione SSH gira nel contesto "Background",
# dove la firma e' NEGATA e codesign fallisce con errSecInternalComponent, un
# errore che parla di framework e manda fuori strada. Il lavoro va consegnato
# alla sessione "Aqua", quella dell'utente collegato allo schermo. Il Mac deve
# restare acceso con l'utente collegato: schermo spento e blocco con password
# non danno fastidio, il logout si'.

set -e
set -o pipefail
trap 'echo "### FALLITO"' ZERR

APP="$1"
MODO="${2:-tutto}"
if [[ "$APP" != "customer" && "$APP" != "driver" ]]; then
  echo "Uso: build-ios-mac.sh customer|driver [esporta]"
  exit 1
fi

REPO="${0:A:h}"

# --- consegna alla sessione grafica, se non ci siamo gia' --------------------
if [[ "$(launchctl managername)" != "Aqua" ]]; then
  LABEL="lenny.store.$APP"
  PLIST="/tmp/$LABEL.plist"
  LOG="/tmp/$LABEL.log"
  ME="${0:A}"
  rm -f "$LOG"
  cat > "$PLIST" <<PLIST_FINE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>$ME</string>
    <string>$APP</string>
    <string>$MODO</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_FINE
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "### consegnato alla sessione grafica, seguo il registro ($LOG)"
  giri=0
  while ! grep -qE "### fatto|### FALLITO" "$LOG" 2>/dev/null; do
    sleep 10
    giri=$((giri+1))
    if [[ $giri -gt 240 ]]; then
      echo "### FALLITO: nessuna risposta dopo 40 minuti"
      cat "$LOG" 2>/dev/null
      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      exit 1
    fi
  done
  cat "$LOG"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  grep -q "### fatto" "$LOG" && exit 0 || exit 1
fi

KEY="/Users/titanodevstudio/.appstoreconnect/private_keys/AuthKey_ZSR6KF48RK.p8"
KID="ZSR6KF48RK"
ISS="ed3ff578-1aa7-46bf-a803-f1a393afa2fb"
export PATH="/Users/titanodevstudio/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# CocoaPods vuole un terminale UTF-8: nella sessione grafica LANG non e'
# impostata e pod install muore dentro il SUO rapporto d'errore.
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
# Se un giorno entra audio_session fra le dipendenze: a 0 esclude il codice del
# microfono, senza il quale Apple SCARTA la build dopo il caricamento
# (ITMS-90683, pagato su lane il 15/09/2026). Innocua finche' non serve.
export AUDIO_SESSION_MICROPHONE=0

cd "$REPO/$APP"

if [[ "$MODO" == "esporta" ]]; then
  echo "### solo esportazione dall'archivio esistente"
  [[ -d build/ios/archive/Runner.xcarchive ]] || { echo "### FALLITO: nessun archivio da esportare"; exit 1; }
else
  # --- dipendenze -----------------------------------------------------------
  echo "### $(date '+%H:%M:%S') pacchetti Dart"
  flutter pub get 2>&1 | tail -2

  # L'app driver usa mek_stripe_terminal, che dalla 5.7 e' SOLO Swift Package
  # Manager: con i soli pod la compilazione si ferma su "module not found".
  if [[ "$APP" == "driver" ]]; then
    flutter config --enable-swift-package-manager >/dev/null 2>&1 || true
  fi

  echo "### $(date '+%H:%M:%S') compilazione"
  flutter build ios --release --no-codesign 2>&1 | tail -5

  # I pod di Stripe si scaricano da GitHub e la clonazione cade facilmente a
  # meta' ("RPC failed", "early EOF"): si riprova fino a tre volte.
  echo "### $(date '+%H:%M:%S') pod iOS"
  pod_ok=0
  for tentativo in 1 2 3; do
    if (cd ios && pod install 2>&1 | grep -E "Installing|error|Error|fatal|Pod installation complete" | tail -6); then
      pod_ok=1
      break
    fi
    echo "### pod install non riuscito (tentativo $tentativo di 3), riprovo tra 20 secondi"
    sleep 20
  done
  [[ $pod_ok -eq 1 ]] || { echo "### FALLITO: pod install (di solito e' la rete verso GitHub)"; exit 1; }

  echo "### $(date '+%H:%M:%S') archivio"
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
    -archivePath build/ios/archive/Runner.xcarchive \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS" \
    archive 2>&1 | grep -E "errSec|error:|ARCHIVE (SUCCEEDED|FAILED)" | tail -10
  [[ -d build/ios/archive/Runner.xcarchive ]] || { echo "### FALLITO: nessun archivio prodotto"; exit 1; }
fi

echo "### $(date '+%H:%M:%S') esportazione"
# Cartella pulita: se l'esportazione fallisce NON deve restare una ipa vecchia
# da copiare col nome nuovo (successo su lane il 07/09/2026: caricata la
# versione precedente col numero di quella nuova).
rm -rf build/ios/ipa
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS" 2>&1 \
  | grep -E "errSec|error:|EXPORT (SUCCEEDED|FAILED)|Exported" | tail -10 || true

IPA=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1)
[[ -n "$IPA" ]] || { echo "### FALLITO: nessuna ipa esportata (vedi build/ios/ipa/Packaging.log)"; exit 1; }

# La ipa deve contenere la versione che dice il pubspec: guardia contro il
# pacchetto vecchio ribattezzato col nome nuovo.
VER=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' \r')
unzip -p "$IPA" 'Payload/Runner.app/Info.plist' > /tmp/lenny_ipa_info.plist
DENTRO="$(plutil -extract CFBundleShortVersionString raw /tmp/lenny_ipa_info.plist)+$(plutil -extract CFBundleVersion raw /tmp/lenny_ipa_info.plist)"
[[ "$DENTRO" == "$VER" ]] || { echo "### FALLITO: la ipa contiene $DENTRO, il pubspec dice $VER"; exit 1; }
echo "### ipa verificata: $DENTRO"

# I simboli servono a Crashlytics per tradurre i crash in righe di codice:
# senza, la dashboard resta con "arresto anomalo non elaborato".
echo "### simboli a Crashlytics"
UPL=""
for c in ios/Pods/FirebaseCrashlytics/upload-symbols \
         build/ios/archive/Runner.xcarchive/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols; do
  [[ -x "$c" ]] && { UPL="$c"; break; }
done
if [[ -n "$UPL" ]]; then
  "$UPL" -gsp ios/Runner/GoogleService-Info.plist -p ios \
    build/ios/archive/Runner.xcarchive/dSYMs 2>&1 | tail -3
else
  echo "### caricatore dei simboli non trovato (Crashlytics avvisera')"
fi

# Copia in cartella con nome parlante: app + versione + numero di build, la
# stessa convenzione degli .aab su Windows.
DEST="$HOME/Desktop/ipa app store/lenny"
mkdir -p "$DEST"
FINALE="$DEST/lenny-$APP-${VER%%+*}-vc${VER##*+}.ipa"
cp "$IPA" "$FINALE"

echo "### fatto"
ls -la "$FINALE"
