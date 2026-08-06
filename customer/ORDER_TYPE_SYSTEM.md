# Sistema di Selezione Tipo Ordine

## Panoramica
Il cliente sceglie tra **RITIRO** e **CONSEGNA**: la scelta filtra i ristoranti
mostrati (zone consegnabili, costi per zona) ed e' una decisione di prodotto
voluta. La scelta viene **persistita**: il full-screen di selezione compare
solo al primo avvio assoluto; dagli avvii successivi si riparte dall'ultima
scelta (e dall'ultimo indirizzo) e si cambia dal badge in home.

## Componenti

### 1. OrderTypeDialog (`lib/widgets/order_type_dialog.dart`)
Full-screen mostrato SOLO se non e' mai stata fatta una scelta
(`hasSelectedOrderType` persistito falso):
- **Consegna a domicilio**: ospite → posizione GPS (non bloccante);
  loggato → `DeliveryAddressSelectionScreen`
- **Ritiro al ristorante**: nessuna restrizione geografica
- Sotto i due bottoni c'e' solo una riga informativa. Il vecchio blocco
  tutorial (badge dimostrativi + warning) e' stato sostituito da un
  coach-mark una tantum sul badge reale in home (`_maybeShowOrderTypeHint`).

### 2. LocationProvider (`lib/providers/location_provider.dart`)
- `orderType`, `hasSelectedOrderType`, `isPickup`/`isDelivery`
- `setOrderType(type)`: imposta E PERSISTE (chiavi `order_type`,
  `order_type_selected` in SharedPreferences)
- `selectAddress(address)`: persiste l'indirizzo scelto come JSON
  (`selected_address_json`), ripristinato a freddo in `initialize()`
- `resetOrderTypeSelection()`: azzera anche la persistenza
- `reset()` (logout): dimentica l'indirizzo (legato all'account),
  MANTIENE la scelta consegna/ritiro (vale anche per l'ospite)

### 3. Badge in home (`lib/screens/home_screen.dart`)
- Badge GIALLO (ritiro) / BLU (consegna) nell'header, tap → riapre il dialog
- Coach-mark una tantum dopo la prima scelta (flag `order_type_hint_shown`)

## Flusso

```
PRIMO AVVIO ASSOLUTO:
  hub categorie → home → OrderTypeDialog (obbligatorio) → scelta persistita
                                                        → coach-mark sul badge

AVVII SUCCESSIVI:
  hub categorie → home diretta con ultima scelta + ultimo indirizzo
  (cambio modalita': tap sul badge in home)
```

## Colori reali
- Ritiro: giallo `#F6E644` (badge) — Consegna: blu `AppColors.primary #0F4E8C`
- Sfondo dialog: crema `#FFF8F0`, card bianca con onda (`_WaveClipper`)

## Note
- Il dialog blocca il back (WillPopScope) finche' non si sceglie
- `RistorantiTab` si aggiorna al cambio di `orderType` via listener
- La persistenza usa SharedPreferences; nessuna chiamata di rete coinvolta

---
**Aggiornato**: 6 Agosto 2026 (Fase 2 restyling: persistenza implementata
davvero, dialog alleggerito, coach-mark; questo documento ora riflette il
codice reale)
