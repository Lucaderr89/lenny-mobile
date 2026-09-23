import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/order.dart';

/// "Non incassato": il driver ha consegnato ma il cliente non ha pagato
/// (niente contanti, POS che non va...). Chiede il motivo, obbligatorio e al
/// massimo di 250 caratteri: e' la sola traccia che l'ufficio avra' per
/// recuperare il credito.
///
/// Widget con stato proprio perche' il campo di testo va liberato solo quando
/// il dialog e' davvero chiuso, animazione di uscita compresa.
class DialogNonIncassato extends StatefulWidget {
  final Order order;

  const DialogNonIncassato({super.key, required this.order});

  /// Il motivo scritto dal driver, o null se ci ha ripensato.
  static Future<String?> chiedi(BuildContext context, {required Order order}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogNonIncassato(order: order),
    );
  }

  static const int lunghezzaMassima = 250;

  @override
  State<DialogNonIncassato> createState() => _DialogNonIncassatoState();
}

class _DialogNonIncassatoState extends State<DialogNonIncassato> {
  final TextEditingController _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _pronto => _motivo.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.money_off,
              color: AppColors.danger,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Non incassato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'ordine risultera\' consegnato ma NON pagato '
              '(€${widget.order.total.toStringAsFixed(2)}). '
              'Scrivi perche\' non hai incassato: e\' obbligatorio.',
              style: TextStyle(fontSize: 14, color: context.cTestoSec),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _motivo,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: DialogNonIncassato.lunghezzaMassima,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Es. cliente senza contanti, POS non funzionante',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'ANNULLA',
            style: TextStyle(color: context.cTestoSec),
          ),
        ),
        ElevatedButton(
          onPressed: _pronto
              ? () => Navigator.of(context).pop(_motivo.text.trim())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text(
            'CONFERMA NON INCASSATO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
