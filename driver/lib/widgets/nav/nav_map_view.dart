import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
import '../../models/location_point.dart';

/// Mappa di navigazione su flutter_map (OpenStreetMap): segue il driver,
/// disegna il percorso e i marker tappa, tasto ricentra.
///
/// Due visuali, con bottone di scambio e scelta RICORDATA:
/// - GUIDA (default, stile Maps): la mappa ruota nella direzione di marcia
///   ED e' inclinata in prospettiva (piano che "sale" davanti, come la
///   navigazione di Maps). flutter_map non ha un tilt nativo: l'effetto e'
///   una trasformazione prospettica sul widget, con la mappa disegnata piu'
///   grande del viewport cosi' l'inclinazione non lascia buchi ai bordi.
///   La freccia resta ferma verso l'alto e la camera guarda un po' avanti:
///   il mezzo sta in basso, la strada arriva incontro.
/// - NORD: mappa piatta fissa a nord, ruota solo la freccia.
///
/// L'heading GPS a bassa velocita' gira a vuoto: sotto la soglia si congela
/// l'ultimo valore valido, quindi da fermi la mappa non balla.
class NavMapView extends StatefulWidget {
  final ValueListenable<LocationPoint?> posizione;

  /// Geometria del percorso, gia' convertita in LatLng (lat, lng).
  final List<LatLng> percorso;

  /// Marker delle tappe (li costruisce il chiamante, con rotate: true
  /// cosi' restano dritti anche quando la mappa ruota).
  final List<Marker> tappeMarkers;

  /// Quanto alzare i tasti dal fondo (es. sopra la card tappa).
  final double recenterBottomInset;

  /// Centro di ripiego se non c'e' ancora un fix GPS (San Marino).
  final LatLng fallbackCenter;

  /// Controller iniettabile: serve ai TEST per osservare la camera
  /// (centro e rotazione) mentre si simula un tragitto. In app resta null
  /// e la mappa usa il proprio.
  final MapController? controller;

  const NavMapView({
    super.key,
    required this.posizione,
    required this.percorso,
    required this.tappeMarkers,
    this.recenterBottomInset = 16,
    this.fallbackCenter = const LatLng(43.9424, 12.4578),
    this.controller,
  });

  @override
  State<NavMapView> createState() => _NavMapViewState();
}

class _NavMapViewState extends State<NavMapView> {
  static const double _zoomGuida = 17.5;
  static const double _zoomNord = 16.5;

  /// In visuale guida la camera punta questo tanto di metri AVANTI al
  /// mezzo lungo la direzione di marcia: il driver finisce nella parte
  /// bassa dello schermo e si vede la strada che arriva, come su Maps.
  static const double _metriAvanti = 150;

  /// Inclinazione del piano in visuale guida (radianti, ~30 gradi) e
  /// prospettiva della trasformazione. Valori piu' alti = effetto piu'
  /// marcato ma tile piu' stirate in cima.
  static const double _inclinazione = 0.55;
  static const double _prospettiva = 0.0013;

  /// La mappa inclinata si restringe verso l'alto: va disegnata piu'
  /// grande del viewport per coprire i bordi dopo la trasformazione.
  static const double _sovradimensione = 1.6;

  /// Sotto questa velocita' (km/h) l'heading GPS gira a vuoto: si congela
  /// l'ultimo valore valido (la freccia ferma al semaforo non deve ruotare).
  static const double _velocitaMinimaHeadingKmh = 5.4;

  static const String _chiavePrefVista = 'vista_guida_driver';

  /// Tile OSM invertite in scala di grigi: fondo scuro, strade chiare.
  /// Niente colori "alieni" (l'inversione pura rende l'acqua arancione).
  static const ColorFilter _filtroNotte = ColorFilter.matrix(<double>[
    -0.2126, -0.7152, -0.0722, 0, 255,
    -0.2126, -0.7152, -0.0722, 0, 255,
    -0.2126, -0.7152, -0.0722, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  late final MapController _map = widget.controller ?? MapController();
  LocationPoint? _pos;
  double _heading = 0;
  bool _vistaGuida = true;
  bool _following = true;
  bool _mapReady = false;
  DateTime? _lastCam;

  @override
  void initState() {
    super.initState();
    _pos = widget.posizione.value;
    _aggiornaHeading(_pos);
    widget.posizione.addListener(_onPos);
    _caricaVista();
  }

  @override
  void dispose() {
    widget.posizione.removeListener(_onPos);
    super.dispose();
  }

  Future<void> _caricaVista() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guida = prefs.getBool(_chiavePrefVista) ?? true;
      if (mounted && guida != _vistaGuida) {
        setState(() => _vistaGuida = guida);
        _applicaCamera();
      }
    } catch (_) {}
  }

  Future<void> _cambiaVista() async {
    setState(() => _vistaGuida = !_vistaGuida);
    _following = true;
    _applicaCamera();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chiavePrefVista, _vistaGuida);
    } catch (_) {}
  }

  void _aggiornaHeading(LocationPoint? pos) {
    final heading = pos?.heading;
    final speed = pos?.speed ?? 0;
    if (heading != null && heading >= 0 && speed >= _velocitaMinimaHeadingKmh) {
      _heading = heading;
    }
  }

  /// Punto [metri] piu' avanti lungo la direzione di marcia.
  LatLng _puntoAvanti(LocationPoint pos, double metri) {
    final h = _heading * math.pi / 180;
    final dLat = metri * math.cos(h) / 111320.0;
    final dLng = metri *
        math.sin(h) /
        (111320.0 * math.cos(pos.latitude * math.pi / 180));
    return LatLng(pos.latitude + dLat, pos.longitude + dLng);
  }

  void _applicaCamera() {
    final pos = _pos;
    if (pos == null || !_mapReady || !_following) return;
    if (_vistaGuida) {
      // Direzione di marcia verso l'alto + camera un po' avanti al mezzo
      _map.moveAndRotate(_puntoAvanti(pos, _metriAvanti), _zoomGuida, -_heading);
    } else {
      _map.moveAndRotate(
        LatLng(pos.latitude, pos.longitude),
        _zoomNord,
        0,
      );
    }
  }

  void _onPos() {
    final pos = widget.posizione.value;
    if (pos == null || !mounted) return;
    _aggiornaHeading(pos);
    final now = DateTime.now();
    // Throttle: sotto i 600 ms si aggiorna il dato ma non si ridisegna.
    if (_lastCam != null && now.difference(_lastCam!).inMilliseconds < 600) {
      _pos = pos;
      return;
    }
    _lastCam = now;
    setState(() => _pos = pos);
    _applicaCamera();
  }

  void _ricentra() {
    setState(() => _following = true);
    _applicaCamera();
  }

  /// Effetto navigatore: piano inclinato in prospettiva, cerniera sul bordo
  /// basso (il mezzo resta a grandezza naturale, la strada "sale" davanti).
  /// La mappa e' disegnata piu' grande del viewport (sovradimensione) perche'
  /// inclinandola si restringe verso l'alto e ai lati; il ClipRect ritaglia.
  Widget _pianoInclinato(Widget mappa) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        final larghezza = vincoli.maxWidth * _sovradimensione;
        final altezza = vincoli.maxHeight * _sovradimensione;
        return ClipRect(
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, _prospettiva)
              ..rotateX(-_inclinazione),
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minWidth: 0,
              minHeight: 0,
              maxWidth: larghezza,
              maxHeight: altezza,
              child: SizedBox(
                width: larghezza,
                height: altezza,
                child: mappa,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notte = context.notte;
    final center = _pos != null
        ? LatLng(_pos!.latitude, _pos!.longitude)
        : widget.fallbackCenter;

    final tileLayer = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      // Richiesto dalla usage policy di tile.openstreetmap.org
      userAgentPackageName: 'com.lenny.drivers',
    );

    final markers = <Marker>[
      ...widget.tappeMarkers,
      if (_pos != null)
        Marker(
          point: LatLng(_pos!.latitude, _pos!.longitude),
          width: 44,
          height: 44,
          // rotate: true = il marker si raddrizza rispetto alla rotazione
          // della mappa. In guida la freccia punta sempre in alto (e' la
          // mappa che gira); a nord ruota la freccia con l'heading.
          rotate: true,
          child: Transform.rotate(
            angle: _vistaGuida ? 0 : _heading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: context.cPrimario,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
    ];

    final mappa = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _zoomGuida,
        // La rotazione la comanda solo la visuale guida, non il gesto
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          _applicaCamera();
        },
        onPositionChanged: (position, hasGesture) {
          // L'utente ha toccato la mappa: la camera smette di inseguire
          if (hasGesture && _following) {
            setState(() => _following = false);
          }
        },
      ),
      children: [
        if (notte)
          ColorFiltered(colorFilter: _filtroNotte, child: tileLayer)
        else
          tileLayer,
        if (widget.percorso.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.percorso,
                strokeWidth: 7,
                color: notte ? AppColors.nightPrimary : AppColors.primary,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: _vistaGuida ? _pianoInclinato(mappa) : mappa,
        ),
        // Attribution obbligatoria OSM: fuori dal piano inclinato, cosi'
        // resta dritta e leggibile in entrambe le visuali.
        Positioned(
          left: 10,
          bottom: widget.recenterBottomInset,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.cCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: context.cTestoSec),
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: widget.recenterBottomInset,
          child: Column(
            children: [
              // Scambio visuale: guida (mappa che ruota) <-> nord fisso
              Material(
                color: context.cCard.withValues(alpha: 0.96),
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _cambiaVista,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: _vistaGuida
                        ? Icon(
                            Icons.explore_outlined,
                            color: context.cPrimario,
                            size: 22,
                          )
                        : Icon(
                            Icons.assistant_navigation,
                            color: context.cPrimario,
                            size: 22,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: context.cCard.withValues(alpha: 0.96),
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _ricentra,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(
                      _following
                          ? Icons.my_location
                          : Icons.location_searching,
                      color: context.cPrimario,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
