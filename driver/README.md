# Lenny Driver App

App mobile Flutter per i driver di consegna Lenny.

## Struttura

```
lib/
├── config/                 # Configurazioni app
│   ├── app_colors.dart    # Colori tema
│   ├── app_constants.dart # Costanti e API endpoints
│   ├── app_router.dart    # Routing con GoRouter
│   └── app_theme.dart     # Tema Material Design
├── models/                # Modelli dati
│   ├── driver.dart        # Modello Driver
│   └── auth_response.dart # Risposta autenticazione
├── screens/               # Schermate UI
│   ├── splash_screen.dart # Splash iniziale
│   └── login_screen.dart  # Login driver
└── services/              # Servizi business logic
    └── auth_service.dart  # Servizio autenticazione

```

## Setup

1. Installa le dipendenze:
   ```bash
   cd mobile/driver
   flutter pub get
   ```

2. Aggiungi la colonna `api_token` alla tabella drivers:
   ```sql
   -- Esegui il file migration_drivers_api_token.sql
   ALTER TABLE drivers ADD COLUMN api_token VARCHAR(255) NULL DEFAULT NULL AFTER password;
   ```

3. Configura l'IP del server in `lib/config/app_constants.dart`:
   ```dart
   static const String baseUrl = 'http://TUO_IP/staging';
   ```

## Esecuzione

### Via Android Studio / VS Code
- Apri il progetto `mobile/driver` in VS Code o Android Studio
- Premi F5 o usa "Run > Run Without Debugging"

### Via Batch File
```bash
# Dalla root del progetto staging
run_driver_app.bat
```

## Funzionalità Implementate

### ✅ Fase 1 - Autenticazione
- [x] Splash screen con animazione
- [x] Login con email/password
- [x] Autenticazione API con tabella `drivers`
- [x] Salvataggio sessione locale
- [x] Bottone registrazione (UI placeholder)

### 🚧 Fase 2 - Da Implementare
- [ ] Schermata registrazione driver
- [ ] Home con lista ordini
- [ ] Dettaglio ordine
- [ ] Navigazione GPS
- [ ] Aggiornamento posizione real-time
- [ ] Gestione stato disponibilità

## API Endpoints

### Autenticazione
```
POST /api/driver/login
Body: {
  "email": "driver@example.com",
  "password": "password"
}
Response: {
  "success": true,
  "data": {
    "driver": { ... },
    "api_token": "...",
    "session_id": "..."
  }
}
```

## Credenziali Test

Driver di test disponibili nel DB (password: `Lenny2024!`):

| Email | Nome |
|-------|------|
| marco.bianchi@lenny.sm | Marco Bianchi |
| luca.ferrari@lenny.sm | Luca Ferrari |
| giovanni.rossi@lenny.sm | Giovanni Rossi |

## Note Tecniche

### Differenze vs Customer App
- **Colori**: Blu (#2196F3) invece di rosso/arancione
- **Splash**: Icona delivery invece del logo Lenny
- **Login**: NO social login (solo email/password)
- **Onboarding**: Rimosso, si va direttamente al login

### Database
La tabella `drivers` contiene:
- Dati anagrafici (name, email, phone, address)
- Stato lavorativo (`employment_status`: active/inactive/suspended)
- Punto di partenza (starting_point con lat/lng)
- Token API per autenticazione mobile

### Prossimi Passi
1. Implementare schermata home con ordini assegnati
2. Aggiungere geolocalizzazione continua
3. Implementare aggiornamento stato ordine
4. Aggiungere notifiche push per nuovi ordini
