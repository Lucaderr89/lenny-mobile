import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/app_colors.dart';
import '../logic/nav_guidance.dart';
import '../logic/regole_home.dart';
import '../models/location_point.dart';
import '../models/nav_route.dart';
import '../models/order.dart';
import '../services/driver_location_service.dart';
import '../services/geofence_tracking_service.dart';
import '../services/nav_route_service.dart';
import '../widgets/nav/nav_banner.dart';
import '../widgets/nav/nav_map_view.dart';
import '../widgets/nav/nav_shared.dart';

/// Navigazione integrata: mappa OSM col percorso della gamba corrente
/// (GPS -> tappa), banner manovra coi metri che scalano, avanzamento
/// automatico alla tappa dopo quando il geofencing server la chiude,
/// voce SPENTA di default. "Apri in Google Maps" resta come via di fuga.
///
/// La schermata NON apre un secondo stream GPS: ascolta
/// GeofenceTrackingService().ultimaPosizione (lo stream del geofencing,
/// acceso finche' ci sono ordini attivi) e scopre i cambi di stato dalla
/// risposta di track-location (statiOrdini) oltre che dal polling della
/// home (ordiniLive).
class NavigationScreen extends StatefulWidget {
  /// True mentre una NavigationScreen e' montata: la home lo consulta per
  /// NON spegnere il wakelock sotto la navigazione quando l'ultimo ordine
  /// si chiude (il suo polling continua a girare sotto questa schermata).
  static bool schermataAperta = false;

  /// Ordini del giro (anche uno solo). Sono ESATTAMENTE gli ordini della
  /// card da cui e' partito il NAVIGA: mai ricostruiti per fascia, cosi'
  /// la navigazione mostra lo stesso giro che il driver ha appena guardato.
  final List<Order> ordini;

  /// Sequenza tappe: route_plan del pannello (gia' filtrato dalla card),
  /// giro sintetico o ritiro+consegna del singolo ordine.
  final List<RouteStop> tappe;

  /// Ordini attivi della home, aggiornati dal polling: quando un ordine
  /// sparisce (consegnato) o cambia stato, il cursore tappa si sposta.
  final ValueListenable<List<Order>> ordiniLive;

  /// Via di fuga: bolla + Google Maps, come il vecchio NAVIGA.
  final void Function(Order ordine, double lat, double lng, String label)
  onNavigaEsterno;

  /// Conferma consegna: riusa il flusso della home (dialog pagamento
  /// offline incluso). La tappa si chiude al reload ordini che segue.
  final Future<void> Function(Order ordine) onConsegnato;

  const NavigationScreen({
    super.key,
    required this.ordini,
    required this.tappe,
    required this.ordiniLive,
    required this.onNavigaEsterno,
    required this.onConsegnato,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  /// CONSEGNATO compare sotto questa distanza dalla tappa di consegna.
  static const double _distanzaConsegnaM = 100;

  /// Minimo fra due ricalcoli per uscita dal percorso.
  static const Duration _minTraRicalcoli = Duration(seconds: 10);

  /// Un fix piu' vecchio di cosi' non e' un'origine affidabile: se ne
  /// chiede uno fresco all'apertura (il giro precedente puo' essere
  /// finito ore fa, dall'altra parte del Titano).
  static const Duration _etaMassimaFix = Duration(seconds: 60);

  final GeofenceTrackingService _tracking = GeofenceTrackingService();
  final NavRouteService _routeService = NavRouteService();
  final NavVoice _voce = NavVoice();

  late Set<int> _idsGiro;
  late List<Order> _ordini;
  Map<int, Order> _orderById = {};

  RouteStop? _tappa;
  NavGuidance? _guidance;
  List<LatLng> _percorso = const [];
  List<Marker> _tappeMarkers = const [];
  ManovraCorrente? _manovra;
  int? _metriArrivo;

  bool _fetchInCorso = false;
  bool _refetchRichiesto = false;
  bool _fuoriGrafo = false;
  bool _motoreGiu = false;
  bool _gpsAssente = false;
  bool _giroCompletato = false;
  bool _vicinoAllaConsegna = false;
  DateTime? _ultimoRicalcolo;

  NavRoute? get _route => _guidance?.route;

  @override
  void initState() {
    super.initState();
    NavigationScreen.schermataAperta = true;
    WidgetsBinding.instance.addObserver(this);
    // Difesa: se l'ultimo ordine si chiude mentre la nav e' aperta, la home
    // spegnerebbe il wakelock sotto di noi (vedi anche schermataAperta).
    WakelockPlus.enable();

    _idsGiro = widget.ordini.map((o) => o.id).toSet();
    _ordini = widget.ordini;
    _orderById = {for (final o in _ordini) o.id: o};

    _voce.init().then((_) {
      if (mounted) setState(() {});
    });

    _tracking.ultimaPosizione.addListener(_onFix);
    _tracking.statiOrdini.addListener(_onStati);
    widget.ordiniLive.addListener(_onOrdiniLive);

    _ricomputaTappa(annuncia: false);
    _seedGps();
  }

  @override
  void dispose() {
    NavigationScreen.schermataAperta = false;
    WidgetsBinding.instance.removeObserver(this);
    _tracking.ultimaPosizione.removeListener(_onFix);
    _tracking.statiOrdini.removeListener(_onStati);
    widget.ordiniLive.removeListener(_onOrdiniLive);
    _voce.stop();
    // Il wakelock torna alla regola della home: acceso solo con ordini attivi.
    WakelockPlus.toggle(enable: widget.ordiniLive.value.isNotEmpty);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rientro nell'app: la posizione puo' essere cambiata parecchio,
    // meglio una rotta fresca che una geometria vecchia.
    if (state == AppLifecycleState.resumed && _tappa != null) {
      _seedGps();
      _fetchRoute();
    }
  }

  Map<int, String> get _statiOverride => _tracking.statiOrdini.value;

  Order? get _ordineTappa => _tappa == null ? null : _orderById[_tappa!.orderId];

  bool get _tappaERitiro => _tappa?.isPickup ?? true;

  // ── GPS ────────────────────────────────────────────────────────────────

  /// La schermata non apre uno stream proprio, ma non puo' nemmeno restare
  /// cieca: se il notifier e' vuoto (tracking non partito: permesso negato,
  /// GPS di sistema spento) o il fix e' vecchio, chiede UNA posizione al
  /// volo. Se fallisce, la card lo dice invece di mostrare una mappa muta.
  Future<void> _seedGps() async {
    final attuale = _tracking.ultimaPosizione.value;
    final fresco =
        attuale != null &&
        DateTime.now().difference(attuale.timestamp) < _etaMassimaFix;
    if (fresco) return;
    try {
      final loc = await DriverLocationService().getCurrentLocation();
      // Passa dal notifier condiviso: cosi' scatta _onFix (fetch compreso).
      _tracking.ultimaPosizione.value = loc;
    } catch (_) {
      if (mounted) setState(() => _gpsAssente = true);
    }
  }

  // ── Reazioni agli eventi ───────────────────────────────────────────────

  void _onOrdiniLive() {
    _ordini = widget.ordiniLive.value
        .where((o) => _idsGiro.contains(o.id))
        .toList();
    _orderById = {for (final o in _ordini) o.id: o};
    _ricomputaTappa(annuncia: true);
  }

  void _onStati() => _ricomputaTappa(annuncia: true);

  void _onFix() {
    final pos = _tracking.ultimaPosizione.value;
    if (pos == null || !mounted) return;

    // La vicinanza alla consegna NON dipende dalla rotta: il bottone
    // CONSEGNATO deve comparire anche a motore giu' o destinazione fuori
    // grafo (e' proprio il caso in cui il driver resta su questa schermata).
    final vicino = _calcolaVicinanzaConsegna(pos);

    final guidance = _guidance;
    if (guidance == null) {
      // Primo fetch rimasto in attesa del GPS (o motore giu': riprova).
      if (!_fetchInCorso && _tappa != null && !_fuoriGrafo) {
        _fetchRoute();
      }
      setState(() {
        _gpsAssente = false;
        _vicinoAllaConsegna = vicino;
      });
      return;
    }

    // UNA proiezione per fix: manovra, metri all'arrivo e fuori-percorso
    // la riusano tutti.
    final p = guidance.proietta(pos.latitude, pos.longitude);
    final manovra = guidance.prossimaManovraDa(p);
    final metriArrivo = guidance.metriAllArrivoDa(p);

    if (manovra != null) {
      _voce.announce(manovra.istruzione, manovra.metriRestanti);
    }

    // Uscita dal percorso: ricalcolo immediato (con lock e distanza minima
    // fra due ricalcoli), invece di aspettare un refresh a tempo.
    final fuori = guidance.registraProiezione(p, accuracy: pos.accuracy);
    if (fuori && !_fetchInCorso) {
      final ora = DateTime.now();
      if (_ultimoRicalcolo == null ||
          ora.difference(_ultimoRicalcolo!) > _minTraRicalcoli) {
        _ultimoRicalcolo = ora;
        _mostraToast('Ricalcolo percorso');
        _fetchRoute();
      }
    }

    setState(() {
      _gpsAssente = false;
      _manovra = manovra;
      _metriArrivo = metriArrivo;
      _vicinoAllaConsegna = vicino;
    });
  }

  bool _calcolaVicinanzaConsegna(LocationPoint pos) {
    final tappa = _tappa;
    if (tappa == null || tappa.isPickup) return false;
    final d = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      tappa.lat,
      tappa.lng,
    );
    return d <= _distanzaConsegnaM;
  }

  // ── Cursore tappa e rotta ──────────────────────────────────────────────

  void _ricomputaTappa({required bool annuncia}) {
    final nuova = RegoleHome.prossimaTappa(
      widget.tappe,
      _orderById,
      statiOverride: _statiOverride,
    );

    if (nuova == null) {
      if (!_giroCompletato) {
        setState(() {
          _giroCompletato = true;
          _tappeMarkers = _buildTappeMarkers();
        });
        _voce.say('Giro completato.');
      }
      return;
    }

    // NB: prossimaTappa restituisce sempre la STESSA istanza di widget.tappe
    // per la stessa tappa logica, quindi il confronto per identita' regge.
    final cambiata = !identical(_tappa, nuova);
    if (!cambiata) {
      // Stessa tappa: possono essere cambiati gli stati (picking_up, o la
      // lista ordini tornata dopo un vuoto transitorio) → niente latch su
      // "giro completato", si riprende da dove si era.
      setState(() {
        _giroCompletato = false;
        _tappeMarkers = _buildTappeMarkers();
      });
      return;
    }

    final eraRitiro = _tappaERitiro;
    final avevaTappa = _tappa != null;
    setState(() {
      _tappa = nuova;
      _giroCompletato = false;
      _fuoriGrafo = false;
      _tappeMarkers = _buildTappeMarkers();
    });

    if (annuncia && avevaTappa) {
      final o = _orderById[nuova.orderId];
      final dove = nuova.isPickup
          ? (o?.restaurantName ?? 'ritiro')
          : (o?.customerName ?? 'consegna');
      _voce.say(
        eraRitiro
            ? 'Ritiro completato. Prossima tappa: $dove.'
            : 'Consegna completata. Prossima tappa: $dove.',
      );
    }

    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final tappa = _tappa;
    if (tappa == null) return;
    if (_fetchInCorso) {
      // Richiesta in volo per una tappa che potrebbe essere gia' vecchia:
      // segnati di rifare il giro appena si libera.
      _refetchRichiesto = true;
      return;
    }
    final pos = _tracking.ultimaPosizione.value;
    if (pos == null) {
      // Nessun fix ancora: _onFix (o il seed) riprovera' al primo punto.
      return;
    }

    _fetchInCorso = true;
    try {
      final route = await _routeService.fetchRoute(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: tappa.lat,
        toLng: tappa.lng,
      );
      if (!mounted) return;
      if (!identical(tappa, _tappa)) {
        // La tappa e' avanzata mentre la risposta era in volo: questa rotta
        // guida verso una tappa GIA' CHIUSA, va buttata e rifatta.
        _refetchRichiesto = true;
        return;
      }
      _voce.reset();
      setState(() {
        _guidance = NavGuidance(route);
        _percorso = [
          for (final c in route.coordinates) LatLng(c[1], c[0]),
        ];
        _manovra = null;
        _metriArrivo = route.distanceM;
        _fuoriGrafo = false;
        _motoreGiu = false;
      });
    } on NavOutOfGraphException {
      if (!mounted) return;
      if (!identical(tappa, _tappa)) {
        _refetchRichiesto = true;
        return;
      }
      setState(() {
        _guidance = null;
        _percorso = const [];
        _manovra = null;
        _fuoriGrafo = true;
        _motoreGiu = false;
      });
    } on NavUnavailableException {
      if (!mounted) return;
      if (!identical(tappa, _tappa)) {
        _refetchRichiesto = true;
        return;
      }
      // Si tiene l'ultima rotta buona, se c'e': meglio una geometria
      // leggermente vecchia che uno schermo vuoto.
      setState(() => _motoreGiu = true);
    } finally {
      _fetchInCorso = false;
      if (_refetchRichiesto && mounted) {
        _refetchRichiesto = false;
        _fetchRoute();
      }
    }
  }

  // ── Azioni ─────────────────────────────────────────────────────────────

  Future<void> _toggleVoce() async {
    await _voce.setEnabled(!_voce.enabled);
    if (_voce.enabled) {
      _voce.say('Voce del navigatore attiva.');
    }
    if (mounted) setState(() {});
  }

  void _apriMapsEsterno() {
    final o = _ordineTappa;
    final tappa = _tappa;
    if (o == null || tappa == null) return;
    widget.onNavigaEsterno(
      o,
      tappa.lat,
      tappa.lng,
      _tappaERitiro ? o.restaurantName : o.customerName,
    );
  }

  Future<void> _confermaConsegna() async {
    final o = _ordineTappa;
    if (o == null) return;
    await widget.onConsegnato(o);
    // Il reload ordini della home aggiorna ordiniLive → il cursore avanza.
  }

  Future<void> _chiamaTelefono(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _mostraToast(String messaggio) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cSfondo,
      body: Stack(
        children: [
          Positioned.fill(
            child: NavMapView(
              posizione: _tracking.ultimaPosizione,
              percorso: _percorso,
              tappeMarkers: _tappeMarkers,
              recenterBottomInset: 235,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 12),
                  child: Material(
                    color: context.cCard.withValues(alpha: 0.96),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(
                          Icons.arrow_back,
                          color: context.cTesto,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBanner(context)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _giroCompletato
                ? _buildCardCompletato(context)
                : _buildCardTappa(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final o = _ordineTappa;
    final ritiro = _tappaERitiro;
    final colore = ritiro ? AppColors.primary : AppColors.success;

    if (_giroCompletato) {
      return const NavBanner(
        icona: Icons.flag,
        titolo: 'Giro completato',
        sottotitolo: 'Tutte le tappe sono chiuse',
        colore: AppColors.success,
      );
    }

    final man = _manovra;
    if (man != null && man.istruzione.text.isNotEmpty) {
      final dove = ritiro ? (o?.restaurantName ?? '') : (o?.customerName ?? '');
      return NavBanner(
        icona: navManeuverIcon(man.istruzione.sign),
        titolo: man.istruzione.text,
        sottotitolo: man.metriRestanti > 0
            ? 'tra ${navDistLabel(man.metriRestanti)} - $dove'
            : dove,
        colore: colore,
      );
    }

    return NavBanner(
      icona: ritiro ? Icons.storefront : Icons.location_on,
      titolo: ritiro
          ? 'Verso ${o?.restaurantName ?? 'il ritiro'}'
          : 'Verso ${o?.customerName ?? 'la consegna'}',
      sottotitolo: ritiro
          ? (o?.restaurantAddress ?? '')
          : (o?.deliveryAddress ?? ''),
      colore: colore,
    );
  }

  /// Marker delle tappe ancora aperte. Ricostruiti SOLO quando cambia il
  /// cursore o la lista ordini (_ricomputaTappa), mai a ogni fix GPS.
  /// Non usa il BuildContext: solo colori costanti del brand.
  List<Marker> _buildTappeMarkers() {
    final markers = <Marker>[];
    var numero = 0;
    for (final st in widget.tappe) {
      if (RegoleHome.tappaChiusa(
        st,
        _orderById[st.orderId],
        statiOverride: _statiOverride,
      )) {
        continue;
      }
      numero++;
      final corrente = _tappa != null && identical(st, _tappa);
      final colore = st.isPickup ? AppColors.primary : AppColors.success;
      markers.add(
        Marker(
          point: LatLng(st.lat, st.lng),
          width: corrente ? 40 : 30,
          height: corrente ? 40 : 30,
          child: Container(
            decoration: BoxDecoration(
              color: colore,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: corrente ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$numero',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: corrente ? 16 : 12,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildCardTappa(BuildContext context) {
    final o = _ordineTappa;
    final ritiro = _tappaERitiro;
    final colore = ritiro ? AppColors.primary : AppColors.success;
    // Stessa regola della card giro (RegoleHome), non una copia locale
    final inConsegna =
        _tappa != null &&
        !ritiro &&
        RegoleHome.tappaInCorso(_tappa!, o, statiOverride: _statiOverride);
    final consegnabile = inConsegna && _vicinoAllaConsegna;
    final tappeAperte = _tappeMarkers.length;

    // Riepilogo distanza/tempo della gamba corrente
    String? riepilogo;
    final route = _route;
    if (route != null && route.distanceM > 0) {
      final metri = _metriArrivo ?? route.distanceM;
      final minuti = (route.timeS * (metri / route.distanceM) / 60).ceil();
      riepilogo = '${navDistLabel(metri)} - $minuti min';
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBordo),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ritiro
                            ? 'RITIRA DA ${o?.restaurantName ?? ''}'
                            : 'CONSEGNA A ${o?.customerName ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colore,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ritiro
                            ? (o?.restaurantAddress ?? '')
                            : (o?.deliveryAddress ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.cTestoSec,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (riepilogo != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          riepilogo,
                          style: TextStyle(
                            color: context.cTesto,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tappe rimaste: $tappeAperte',
                          style: TextStyle(
                            color: context.cTestoSec,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (!ritiro &&
                o?.deliveryNotes != null &&
                o!.deliveryNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                o.deliveryNotes!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.cTesto,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_gpsAssente || _fuoriGrafo || _motoreGiu) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _gpsAssente
                      ? 'GPS non disponibile: controlla il permesso di localizzazione e che il GPS sia acceso.'
                      : _fuoriGrafo
                          ? 'Destinazione fuori dalla rete stradale coperta: usa Google Maps.'
                          : 'Percorso non aggiornabile in questo momento.',
                  style: TextStyle(color: context.cTesto, fontSize: 12),
                ),
              ),
            ],
            if (consegnabile) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _confermaConsegna,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'CONSEGNATO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                // Voce: spenta di default, la scelta viene ricordata
                Material(
                  color: _voce.enabled
                      ? colore.withValues(alpha: 0.15)
                      : context.cCardAlta,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _toggleVoce,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _voce.enabled ? Icons.volume_up : Icons.volume_off,
                        color: _voce.enabled ? colore : context.cTestoSec,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (o != null &&
                    !ritiro &&
                    o.customerPhone.trim().isNotEmpty) ...[
                  Material(
                    color: context.cCardAlta,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _chiamaTelefono(o.customerPhone),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.phone,
                          color: context.cTestoSec,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.cTesto,
                        side: BorderSide(color: context.cBordo),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _apriMapsEsterno,
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Apri in Google Maps'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCompletato(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBordo),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'Giro completato',
              style: TextStyle(
                color: context.cTesto,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cPrimario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Torna agli ordini',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
