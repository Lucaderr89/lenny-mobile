import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../models/location_point.dart';

/// Mappa di navigazione su flutter_map (OpenStreetMap): segue il driver,
/// disegna il percorso e i marker tappa, tasto ricentra.
///
/// Riscrittura della NavMapView del progetto taxi (google_maps_flutter):
/// stessi pattern (posizione iniettata come ValueListenable, throttle camera
/// 600 ms, follow spento dal gesto dell'utente), ma mappa NORTH-UP e freccia
/// che ruota da sola: flutter_map non ha tilt, e ruotare la mappa con
/// l'heading GPS instabile a bassa velocita' fa girare tutto lo schermo.
class NavMapView extends StatefulWidget {
  final ValueListenable<LocationPoint?> posizione;

  /// Geometria del percorso, gia' convertita in LatLng (lat, lng).
  final List<LatLng> percorso;

  /// Marker delle tappe (li costruisce il chiamante).
  final List<Marker> tappeMarkers;

  /// Quanto alzare il tasto ricentra dal fondo (es. sopra la card tappa).
  final double recenterBottomInset;

  /// Centro di ripiego se non c'e' ancora un fix GPS (San Marino).
  final LatLng fallbackCenter;

  const NavMapView({
    super.key,
    required this.posizione,
    required this.percorso,
    required this.tappeMarkers,
    this.recenterBottomInset = 16,
    this.fallbackCenter = const LatLng(43.9424, 12.4578),
  });

  @override
  State<NavMapView> createState() => _NavMapViewState();
}

class _NavMapViewState extends State<NavMapView> {
  static const double _zoomGuida = 16.5;

  /// Sotto questa velocita' (km/h) l'heading GPS gira a vuoto: si congela
  /// l'ultimo valore valido (la freccia ferma al semaforo non deve ruotare).
  static const double _velocitaMinimaHeadingKmh = 5.4;

  /// Tile OSM invertite in scala di grigi: fondo scuro, strade chiare.
  /// Niente colori "alieni" (l'inversione pura rende l'acqua arancione).
  static const ColorFilter _filtroNotte = ColorFilter.matrix(<double>[
    -0.2126, -0.7152, -0.0722, 0, 255,
    -0.2126, -0.7152, -0.0722, 0, 255,
    -0.2126, -0.7152, -0.0722, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  final MapController _map = MapController();
  LocationPoint? _pos;
  double _heading = 0;
  bool _following = true;
  bool _mapReady = false;
  DateTime? _lastCam;

  @override
  void initState() {
    super.initState();
    _pos = widget.posizione.value;
    _aggiornaHeading(_pos);
    widget.posizione.addListener(_onPos);
  }

  @override
  void dispose() {
    widget.posizione.removeListener(_onPos);
    super.dispose();
  }

  void _aggiornaHeading(LocationPoint? pos) {
    final heading = pos?.heading;
    final speed = pos?.speed ?? 0;
    if (heading != null && heading >= 0 && speed >= _velocitaMinimaHeadingKmh) {
      _heading = heading;
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
    if (_following && _mapReady) {
      _map.move(LatLng(pos.latitude, pos.longitude), _zoomGuida);
    }
  }

  void _ricentra() {
    setState(() => _following = true);
    final pos = _pos;
    if (pos != null && _mapReady) {
      _map.move(LatLng(pos.latitude, pos.longitude), _zoomGuida);
    }
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
          child: Transform.rotate(
            angle: _heading * math.pi / 180,
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

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _zoomGuida,
              // North-up: rotazione disattivata, ruota solo la freccia
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _mapReady = true,
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
                      color: notte
                          ? AppColors.nightPrimary
                          : AppColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
              // Attribution obbligatoria OSM
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          bottom: widget.recenterBottomInset,
          child: Material(
            color: context.cCard.withValues(alpha: 0.96),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _ricentra,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  _following ? Icons.navigation_rounded : Icons.explore_outlined,
                  color: context.cPrimario,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
