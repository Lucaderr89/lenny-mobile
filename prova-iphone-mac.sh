#!/bin/zsh
# Installa una build PROFILE di un'app Lenny sull'iPhone del committente, via
# WiFi. Gira SUL MAC. Copiato dallo script gemello dell'app lane (taxi), che
# ha gia' pagato le trappole elencate nei commenti.
#
# Uso (dalla sessione Windows, via SSH):
#
#   ssh -i ~/.ssh/id_ed25519_mac titanodevstudio@192.168.1.110 \
#     'cd <clone di lenny-mobile> && zsh prova-iphone-mac.sh customer'
#
# L'argomento e' customer oppure driver.
#
# PERCHE' PROFILE E MAI DEBUG: la debug compila al volo (JIT), e iOS lo consente
# solo con un debugger attaccato. Lanciata dall'icona si chiude da sola, e
# sembra un difetto dell'app quando invece e' la modalita' sbagliata. La profile
# e' compilata in anticipo come la release: parte dall'icona e ha le prestazioni
# della produzione.
#
# ATTENZIONE: ha lo stesso identificativo dell'app di TestFlight e quindi la
# SOSTITUISCE sul telefono. Per tornare a quella dello store basta reinstallarla
# da TestFlight. Si esegue solo quando il committente lo chiede.
#
# La firma DEVE girare nella sessione grafica (portachiavi e prompt di
# sistema): lo script ci si sposta da solo tramite launchctl e poi segue il
# proprio registro.

set -e

APP="$1"
if [[ "$APP" != "customer" && "$APP" != "driver" ]]; then
  echo "Uso: prova-iphone-mac.sh customer|driver"
  exit 1
fi

REPO="${0:A:h}"
IPHONE="328904E0-5769-515D-A7DC-9A89BE329A12"   # "Iphone di Luca" (iPhone Air), come lo vede devicectl su questo Mac
KEY="/Users/titanodevstudio/.appstoreconnect/private_keys/AuthKey_ZSR6KF48RK.p8"
KID="ZSR6KF48RK"
ISS="ed3ff578-1aa7-46bf-a803-f1a393afa2fb"
export PATH="/Users/titanodevstudio/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# CocoaPods vuole un terminale UTF-8: nella sessione grafica (launchctl) LANG
# non e' impostata e pod install muore con "Unicode Normalization not
# appropriate for ASCII-8BIT" dentro il SUO rapporto d'errore.
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# --- consegna alla sessione grafica, se non ci siamo gia' --------------------
if [[ "$(launchctl managername)" != "Aqua" ]]; then
  LABEL="lenny.prova.$APP"
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
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_FINE
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "### consegnato alla sessione grafica, seguo il registro"
  giri=0
  while ! grep -qE "### installata|### FALLITO" "$LOG" 2>/dev/null; do
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
  grep -q "### installata" "$LOG" && exit 0 || exit 1
fi

cd "$REPO/$APP"

# Da qui in poi l'esito di ogni pipe e' quello del comando vero, non di tail.
set -o pipefail

# --- dipendenze: pacchetti Dart, progetto Xcode, pod iOS ---------------------
# xcodebuild NON installa i pod da solo: un plugin nuovo nel pubspec senza
# questo passo fa fallire la compilazione con "module not found". I pod di
# Stripe si scaricano da GitHub e la clonazione cade facilmente a meta'
# ("RPC failed", "early EOF"): si riprova fino a tre volte.
echo "### $(date '+%H:%M:%S') dipendenze: pacchetti Dart"
if ! flutter pub get 2>&1 | tail -2; then
  echo "### FALLITO: flutter pub get"
  exit 1
fi
# L'app driver usa mek_stripe_terminal, che dalla 5.7 e' SOLO Swift Package
# Manager: con i soli pod la compilazione si ferma su "module
# mek_stripe_terminal not found". Il flag e' globale di Flutter e all'app
# cliente non da' fastidio.
if [[ "$APP" == "driver" ]]; then
  flutter config --enable-swift-package-manager >/dev/null 2>&1 || true
fi
echo "### $(date '+%H:%M:%S') dipendenze: progetto Xcode (config-only)"
if ! flutter build ios --profile --config-only 2>&1 | grep -vE "^\s*$" | tail -14; then
  echo "### FALLITO: flutter build ios --config-only"
  exit 1
fi
echo "### $(date '+%H:%M:%S') dipendenze: pod iOS"
pod_ok=0
for tentativo in 1 2 3; do
  if (cd ios && pod install 2>&1 | grep -E "Installing|Downloading|error|Error|fatal|Pod installation complete" | tail -6); then
    pod_ok=1
    break
  fi
  echo "### pod install non riuscito (tentativo $tentativo di 3), riprovo tra 20 secondi"
  sleep 20
done
if [[ $pod_ok -ne 1 ]]; then
  echo "### FALLITO: pod install non riuscito dopo 3 tentativi (di solito e' la rete verso GitHub)"
  exit 1
fi

# --- compilazione -----------------------------------------------------------
# Si parte da prodotti PULITI (resta solo SourcePackages, i pacchetti Swift
# gia' scaricati): cosi' sul telefono finisce SOLO cio' che si compila adesso.
rm -rf build/ios/dev/Build
PACCHETTO="build/ios/dev/Build/Products/Profile-iphoneos/Runner.app"

echo "### $(date '+%H:%M:%S') compilo in profile e firmo per il telefono"
# Destinazione GENERICA, non il telefono: legare la compilazione al
# dispositivo la fa fallire quando l'iPhone non e' raggiungibile in quel
# momento.
if ! xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile \
  -destination "generic/platform=iOS" -derivedDataPath build/ios/dev \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS" \
  build 2>&1 | grep -E "errSec|error:|Signing Identity|BUILD (SUCCEEDED|FAILED)" | tail -8; then
  echo "### FALLITO: compilazione non riuscita, niente da installare"
  exit 1
fi

BUNDLE=$([[ "$APP" == "customer" ]] && echo com.lenny.customer || echo com.lenny.drivers)
if [[ ! -d "$PACCHETTO" ]]; then
  echo "### FALLITO: non trovo $PACCHETTO"
  exit 1
fi
VER="$(plutil -extract CFBundleShortVersionString raw "$PACCHETTO/Info.plist")+$(plutil -extract CFBundleVersion raw "$PACCHETTO/Info.plist")"

# --- installazione ----------------------------------------------------------
# Prima si CANCELLA quella che c'e': una build fallita in silenzio non deve
# lasciare sul telefono la versione vecchia che sembra nuova.
echo "### $(date '+%H:%M:%S') rimuovo la versione presente"
xcrun devicectl device uninstall app --device "$IPHONE" "$BUNDLE" 2>&1 | tail -1 || true

echo "### $(date '+%H:%M:%S') installo sul telefono ($APP $VER)"
if xcrun devicectl device install app --device "$IPHONE" "$PACCHETTO" 2>&1 | tail -4; then
  echo "### installata: $APP $VER"
  # Simboli a Crashlytics anche per la build di prova: senza, un crash di
  # prova resta illeggibile.
  UPL=""
  for c in ios/Pods/FirebaseCrashlytics/upload-symbols build/ios/dev/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols; do
    [[ -x "$c" ]] && { UPL="$c"; break; }
  done
  if [[ -n "$UPL" && -d "$PACCHETTO.dSYM" ]]; then
    echo "### simboli a Crashlytics (build di prova)"
    "$UPL" -gsp ios/Runner/GoogleService-Info.plist -p ios "$PACCHETTO.dSYM" 2>&1 | tail -2
  else
    echo "### simboli non caricati: caricatore o dSYM non trovati (Crashlytics avvisera')"
  fi
else
  echo "### FALLITO: il telefono non e' raggiungibile."
  echo "    Sbloccalo, tienilo sveglio e controlla che sia sulla stessa rete"
  echo "    WiFi del Mac: l'aggancio wireless cade se resta bloccato a lungo."
  exit 1
fi
