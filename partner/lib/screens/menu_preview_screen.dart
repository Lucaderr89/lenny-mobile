import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';

/// Anteprima del menu cosi' come lo vede il cliente nell'app: stessa API
/// pubblica, stessi badge (Consigliato, Piccante, Personalizzabile), stessi
/// vincoli orari ("Disponibile dalle 18:00", "Non disponibile oggi") e
/// stessa resa di sconti e piatti spenti.
class MenuPreviewScreen extends StatefulWidget {
  const MenuPreviewScreen({super.key});

  @override
  State<MenuPreviewScreen> createState() => _MenuPreviewScreenState();
}

class _MenuPreviewScreenState extends State<MenuPreviewScreen> {
  bool _isLoading = true;
  String? _errore;
  List<dynamic> _categorie = [];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _isLoading = true;
      _errore = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final restaurantId = prefs.getInt(AppConstants.keyRestaurantId);
      if (restaurantId == null) {
        throw Exception('Ristorante non riconosciuto: rifai il login');
      }

      final response = await http
          .get(
            Uri.parse('${AppConstants.menuEndpoint}?id=$restaurantId'),
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));
      if (response.statusCode != 200) {
        throw Exception('Errore caricamento menu: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'];
      if (!mounted) return;
      setState(() => _categorie = data is List ? data : []);
    } catch (e) {
      if (mounted) setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Badge e disponibilita': stesse regole dell'app cliente ───────────────

  static List<String> _badges(Map<String, dynamic> piatto) {
    final badges = <String>[];
    if (piatto['is_featured'] == true) badges.add('Consigliato');
    final piccantezza =
        int.tryParse(piatto['spiciness_level']?.toString() ?? '') ?? 0;
    if (piccantezza > 0) badges.add('Piccante');
    final gruppiExtra =
        int.tryParse(piatto['extra_groups_count']?.toString() ?? '') ?? 0;
    if (gruppiExtra > 0) badges.add('Personalizzabile');
    return badges;
  }

  static Color _coloreBadge(String badge) {
    switch (badge.toLowerCase()) {
      case 'bestseller':
      case 'popolare':
        return AppColors.accent;
      case 'nuovo':
        return AppColors.success;
      case 'piccante':
        return AppColors.danger;
      default:
        return AppColors.gray;
    }
  }

  static String? _etichettaDisponibilita(Map<String, dynamic> piatto) {
    final disponibilita = piatto['availability'];
    if (disponibilita is Map<String, dynamic>) {
      return disponibilita['label']?.toString();
    }
    return null;
  }

  static bool _nonDisponibile(Map<String, dynamic> piatto) {
    final etichetta = _etichettaDisponibilita(piatto);
    return etichetta != null &&
        etichetta.toLowerCase().startsWith('non disponibile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Anteprima menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _carica,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errore != null
          ? _buildErrore()
          : _categorie.isEmpty
          ? const Center(
              child: Text(
                'Il menu e\' vuoto',
                style: TextStyle(color: AppColors.gray),
              ),
            )
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Questo e\' il tuo menu come lo vede il cliente '
                            'in questo momento.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._categorie.whereType<Map<String, dynamic>>().map(
                    _buildCategoria,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrore() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _errore!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _carica,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoria(Map<String, dynamic> categoria) {
    final piatti = (categoria['dishes'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (piatti.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banda di sezione come nel menu cliente: barra blu + conteggio
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  categoria['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${piatti.length} ${piatti.length == 1 ? 'piatto' : 'piatti'}',
                style: const TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ],
          ),
        ),
        ...piatti.map(_buildPiatto),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPiatto(Map<String, dynamic> piatto) {
    final nonDisponibile = _nonDisponibile(piatto);
    final etichetta = _etichettaDisponibilita(piatto);
    final badges = _badges(piatto);

    final prezzoBase = double.tryParse(piatto['price']?.toString() ?? '') ?? 0;
    final prezzoScontato = piatto['discounted_price'] != null
        ? double.tryParse(piatto['discounted_price'].toString())
        : null;
    final scontato = prezzoScontato != null && prezzoScontato > 0;

    final immagine = piatto['image_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.lightGray.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Opacity(
        opacity: nonDisponibile ? 0.45 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          piatto['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      if (badges.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: badges
                              .take(2)
                              .map(
                                (badge) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _coloreBadge(badge),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if ((piatto['description']?.toString() ?? '').isNotEmpty)
                    Text(
                      piatto['description'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (etichetta != null) ...[
                    const SizedBox(height: 4),
                    _pillDisponibilita(etichetta, nonDisponibile),
                  ],
                  const SizedBox(height: 6),
                  if (scontato)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EUR ${prezzoBase.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          'EUR ${prezzoScontato.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'EUR ${prezzoBase.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                ],
              ),
            ),
            if (immagine.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  immagine,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Stessa pillola dell'app cliente: rosso = stop, arancione = fascia.
  Widget _pillDisponibilita(String etichetta, bool bloccante) {
    final testo = bloccante ? const Color(0xFFB3261E) : const Color(0xFF9A6400);
    final sfondo = bloccante
        ? const Color(0xFFFDECEA)
        : const Color(0xFFFFF4E5);
    final bordo = bloccante
        ? const Color(0xFFF5C2BD)
        : const Color(0xFFFFD9A0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bordo),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bloccante ? Icons.do_not_disturb_on_outlined : Icons.schedule,
            size: 12,
            color: testo,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              etichetta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: testo,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
