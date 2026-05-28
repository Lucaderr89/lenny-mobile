# 🎯 Sistema di Selezione Tipo Ordine

## Panoramica
Il sistema permette al cliente di scegliere tra **RITIRO** e **CONSEGNA** prima di effettuare un ordine, con logiche differenziate per disponibilità ristoranti e regole di consegna.

## Componenti Implementati

### 1. **OrderTypeDialog** (`order_type_dialog.dart`)
Dialog full-screen obbligatorio che appare all'avvio dell'app:
- **Design**: Gradiente accattivante, icone animate, font Montserrat/Poppins
- **Opzioni**:
  - 🚚 **Consegna a domicilio**: Richiede selezione indirizzo → applica regole zone consegnabili
  - 🏪 **Ritiro al ristorante**: Nessuna restrizione geografica → solo regole orarie/disponibilità

### 2. **DeliveryAddressSelectionScreen** (`delivery_address_selection_screen.dart`)
Schermata per scegliere l'indirizzo di consegna:
- Usa posizione corrente GPS
- Seleziona indirizzo salvato
- Aggiungi nuovo indirizzo
- Design moderno con card colorate e icone

### 3. **LocationProvider Updates**
Nuovi campi e metodi:
- `orderType`: 'delivery' | 'pickup'
- `hasSelectedOrderType`: bool
- `isPickup` / `isDelivery`: getter di convenienza
- `setOrderType(type)`: Imposta il tipo ordine
- `resetOrderTypeSelection()`: Reset selezione

### 4. **RistorantiTab Updates**
Logica condizionale per applicazione regole:
- **Modalità RITIRO**: Tutti i ristoranti disponibili, NO regole zone consegnabili
- **Modalità CONSEGNA**: Applica filtri zone, calcola costi consegna, oscura ristoranti non consegnabili

### 5. **HomeScreen Updates**
Header con indicatore tipo ordine:
- Badge colorato: GIALLO (ritiro) / BLU (consegna)
- Indirizzo visibile solo in modalità consegna
- Tap per cambiare tipo ordine

## Flusso Utente

```
1. Apertura App
   ↓
2. [PRIMA VOLTA] Dialog permessi GPS
   ↓
3. Dialog Selezione Tipo Ordine (OBBLIGATORIO)
   ↓
   ├─→ RITIRO
   │   ↓
   │   • Tutti i ristoranti visibili
   │   • Solo regole orarie/disponibilità
   │   • Messaggio: "Scegli e ritira quando vuoi"
   │   
   └─→ CONSEGNA
       ↓
       • Selezione Indirizzo
       ├─→ Posizione corrente (GPS)
       ├─→ Indirizzo salvato
       └─→ Nuovo indirizzo
       ↓
       • Filtro ristoranti per zone
       • Calcolo costi consegna
       • Oscuramento zone non consegnabili
```

## Design Patterns

### Colori
- **Ritiro**: Giallo (`accentYellow` #FFD042)
- **Consegna**: Blu primario (`primaryBlue` #0F4BCA)
- **Sfondo dialog**: Gradiente Primary → Dark

### Fonts
- **Titoli**: Montserrat (Bold 32px)
- **Body**: Poppins (Regular 14-16px)
- **Labels**: Poppins (Medium 12-13px)

### Responsive
- Font scalati per leggibilità su tutti gli schermi
- Padding adattivo
- Max width per contenuti

## API Backend Richieste

✅ `POST /delivery/calculate-fee` - Calcolo costo consegna
✅ `GET /restaurants/{id}/delivery-zone-rule` - Regole zona per ristorante
✅ `GET /delivery-addresses` - Lista indirizzi salvati

## Testing

### Scenari da testare:
1. ✅ Primo avvio → Dialog GPS → Dialog tipo ordine
2. ✅ Selezione RITIRO → Tutti ristoranti visibili
3. ✅ Selezione CONSEGNA → Richiesta indirizzo
4. ✅ Cambio tipo ordine da header → Ricarica ristoranti
5. ✅ Ristoranti oscurati solo in modalità CONSEGNA
6. ✅ Badge header corretto (colore + icona)
7. ✅ Persistenza selezione tipo ordine

## Note Implementative

- **Non dismissible**: Dialog non chiudibile senza selezione (WillPopScope)
- **Listener automatico**: RistorantiTab si aggiorna quando cambia orderType
- **Graceful degradation**: Se GPS non disponibile, usa indirizzi salvati
- **UX friendly**: Messaggi incoraggianti, icone colorate, animazioni smooth

## Files Modificati/Creati

### Nuovi File
- `lib/widgets/order_type_dialog.dart`
- `lib/screens/delivery_address_selection_screen.dart`

### File Modificati
- `lib/providers/location_provider.dart`
- `lib/screens/tabs/ristoranti_tab.dart`
- `lib/screens/home_screen.dart`

## Comandi per Build

```bash
# Naviga alla directory customer
cd mobile/customer

# Get dependencies
flutter pub get

# Build APK release
flutter build apk --release

# Build APK debug
flutter build apk --debug
```

---
**Creato**: 20 Gennaio 2026  
**Versione**: 1.0.0  
**Status**: ✅ Implementato e Testato
