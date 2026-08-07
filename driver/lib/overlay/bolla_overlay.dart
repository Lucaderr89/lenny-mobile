import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';

/// UI della BOLLA flottante che resta sopra Google Maps durante la
/// navigazione: prossima tappa, note e azioni rapide, senza mai
/// riaprire l'app. Gira in un engine separato (entry point overlayMain).
///
/// Riceve i dati via FlutterOverlayWindow.shareData come JSON:
/// { verbo, soggetto, indirizzo, note, telefono }
class BollaOverlay extends StatefulWidget {
  const BollaOverlay({super.key});

  @override
  State<BollaOverlay> createState() => _BollaOverlayState();
}

class _BollaOverlayState extends State<BollaOverlay> {
  String _verbo = 'PROSSIMA TAPPA';
  String _soggetto = '';
  String _indirizzo = '';
  String _note = '';
  String _telefono = '';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((dati) {
      try {
        final mappa = dati is String
            ? jsonDecode(dati) as Map<String, dynamic>
            : Map<String, dynamic>.from(dati as Map);
        setState(() {
          _verbo = mappa['verbo']?.toString() ?? 'PROSSIMA TAPPA';
          _soggetto = mappa['soggetto']?.toString() ?? '';
          _indirizzo = mappa['indirizzo']?.toString() ?? '';
          _note = mappa['note']?.toString() ?? '';
          _telefono = mappa['telefono']?.toString() ?? '';
        });
      } catch (_) {/* payload inatteso: la bolla resta com'e' */}
    });
  }

  Future<void> _chiama() async {
    if (_telefono.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$_telefono'));
    } catch (_) {}
  }

  Future<void> _apriApp() async {
    try {
      await launchUrl(
        Uri.parse('lennydriver://home'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final bool consegna = _verbo.toUpperCase().contains('CONSEGNA');
    final Color colore = consegna ? AppColors.success : AppColors.primary;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.nightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colore, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    consegna ? Icons.location_on : Icons.storefront,
                    color: colore,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _verbo,
                      style: TextStyle(
                        color: colore,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => FlutterOverlayWindow.closeOverlay(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: AppColors.nightTextSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _soggetto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.nightText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_indirizzo.isNotEmpty)
                Text(
                  _indirizzo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.nightTextSecondary,
                    fontSize: 13,
                  ),
                ),
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD28A),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_telefono.isNotEmpty) ...[
                    Expanded(
                      child: _BottoneBolla(
                        icona: Icons.phone,
                        etichetta: 'CHIAMA',
                        colore: colore,
                        onTap: _chiama,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _BottoneBolla(
                      icona: Icons.open_in_new,
                      etichetta: 'APRI APP',
                      colore: AppColors.nightTextSecondary,
                      onTap: _apriApp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottoneBolla extends StatelessWidget {
  final IconData icona;
  final String etichetta;
  final Color colore;
  final VoidCallback onTap;

  const _BottoneBolla({
    required this.icona,
    required this.etichetta,
    required this.colore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: colore.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colore, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, color: colore, size: 19),
            const SizedBox(width: 6),
            Text(
              etichetta,
              style: TextStyle(
                color: colore,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
