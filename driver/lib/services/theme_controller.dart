import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modalita' del tema scelta dal driver nelle impostazioni.
enum ModalitaTema { automatica, chiara, scura }

/// Governa il tema dell'app: AUTOMATICO col sole (default) o fisso.
///
/// In automatico l'app e' chiara di giorno e NOTTE dal tramonto all'alba,
/// calcolati per San Marino (43.94N, 12.46E) con la formula NOAA
/// semplificata: niente permessi GPS, niente rete, scarto di pochi minuti
/// che qui non conta nulla.
///
/// Un timer ricontrolla ogni 5 minuti (e a ogni resume dell'app via
/// [ricalcola]): al passaggio del sole il tema cambia da solo.
class ThemeController {
  ThemeController._();
  static final ThemeController _instance = ThemeController._();
  factory ThemeController() => _instance;

  static const String _chiavePrefs = 'modalita_tema_driver';

  // San Marino
  static const double _lat = 43.94;
  static const double _lng = 12.46;

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  ModalitaTema _modalita = ModalitaTema.automatica;
  Timer? _orologio;

  ModalitaTema get modalita => _modalita;

  /// Da chiamare una volta all'avvio, prima di runApp (legge solo le prefs).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvata = prefs.getString(_chiavePrefs);
      _modalita = ModalitaTema.values.firstWhere(
        (m) => m.name == salvata,
        orElse: () => ModalitaTema.automatica,
      );
    } catch (_) {
      _modalita = ModalitaTema.automatica;
    }
    ricalcola();
    _orologio?.cancel();
    _orologio = Timer.periodic(
      const Duration(minutes: 5),
      (_) => ricalcola(),
    );
  }

  Future<void> impostaModalita(ModalitaTema nuova) async {
    _modalita = nuova;
    ricalcola();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chiavePrefs, nuova.name);
    } catch (_) {/* al peggio non persiste, ripartira' in automatico */}
  }

  /// Riallinea il tema alla modalita' corrente (chiamabile anche su resume).
  void ricalcola() {
    final ThemeMode nuovo;
    switch (_modalita) {
      case ModalitaTema.chiara:
        nuovo = ThemeMode.light;
      case ModalitaTema.scura:
        nuovo = ThemeMode.dark;
      case ModalitaTema.automatica:
        nuovo = _eNotte(DateTime.now()) ? ThemeMode.dark : ThemeMode.light;
    }
    if (themeMode.value != nuovo) {
      themeMode.value = nuovo;
    }
  }

  /// True se [adesso] e' tra il tramonto e l'alba locali.
  bool _eNotte(DateTime adesso) {
    final alba = _oraSolare(adesso, alba: true);
    final tramonto = _oraSolare(adesso, alba: false);
    if (alba == null || tramonto == null) {
      // Fallback prudente: notte tra le 19 e le 7
      final ora = adesso.hour;
      return ora >= 19 || ora < 7;
    }
    return adesso.isBefore(alba) || adesso.isAfter(tramonto);
  }

  /// Alba o tramonto locali del giorno di [giorno] (formula NOAA
  /// semplificata, zenith ufficiale 90.833 gradi). Null se il calcolo
  /// degenera (non succede a queste latitudini).
  DateTime? _oraSolare(DateTime giorno, {required bool alba}) {
    double gradi(double rad) => rad * 180 / math.pi;
    double rad(double deg) => deg * math.pi / 180;

    final n = DateTime(giorno.year, giorno.month, giorno.day)
            .difference(DateTime(giorno.year, 1, 1))
            .inDays +
        1;

    final lngHour = _lng / 15.0;
    final t = alba ? n + ((6 - lngHour) / 24) : n + ((18 - lngHour) / 24);

    final m = (0.9856 * t) - 3.289;
    var l = m +
        (1.916 * math.sin(rad(m))) +
        (0.020 * math.sin(rad(2 * m))) +
        282.634;
    l = l % 360.0;

    var ra = gradi(math.atan(0.91764 * math.tan(rad(l))));
    ra = ra % 360.0;
    final lQuadrant = (l / 90).floor() * 90.0;
    final raQuadrant = (ra / 90).floor() * 90.0;
    ra = (ra + (lQuadrant - raQuadrant)) / 15.0;

    final sinDec = 0.39782 * math.sin(rad(l));
    final cosDec = math.cos(math.asin(sinDec));

    const zenith = 90.833;
    final cosH = (math.cos(rad(zenith)) - (sinDec * math.sin(rad(_lat)))) /
        (cosDec * math.cos(rad(_lat)));
    if (cosH > 1 || cosH < -1) return null;

    var h = alba ? 360 - gradi(math.acos(cosH)) : gradi(math.acos(cosH));
    h = h / 15.0;

    final tLocale = h + ra - (0.06571 * t) - 6.622;
    var utc = (tLocale - lngHour) % 24.0;
    if (utc < 0) utc += 24;

    final oreUtc = utc.floor();
    final minutiUtc = ((utc - oreUtc) * 60).round();
    return DateTime.utc(
      giorno.year,
      giorno.month,
      giorno.day,
      oreUtc,
      minutiUtc,
    ).toLocal();
  }
}
