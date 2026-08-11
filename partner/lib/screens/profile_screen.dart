import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../services/profile_service.dart';

/// Profilo del ristorante: anagrafica, orari di apertura, zone di consegna
/// e chiusure. La chiusura e' SEMPRE un dal-al (giorni interi o fascia
/// oraria): niente "chiudi e basta", ci si dimentica di riaprire.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();

  bool _isLoading = true;
  String? _errore;
  Map<String, dynamic> _restaurant = {};
  List<dynamic> _orari = [];
  List<dynamic> _zone = [];
  String _zoneScope = 'restaurant';
  List<dynamic> _chiusure = [];

  static const List<String> _giorni = [
    'Domenica',
    'Lunedi\'',
    'Martedi\'',
    'Mercoledi\'',
    'Giovedi\'',
    'Venerdi\'',
    'Sabato',
  ];

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
      final dati = await _service.getProfile();
      if (!mounted) return;
      setState(() {
        _restaurant = (dati['restaurant'] as Map<String, dynamic>? ?? {});
        _orari = dati['opening_hours'] as List<dynamic>? ?? [];
        _zone = dati['delivery_zones'] as List<dynamic>? ?? [];
        _zoneScope = dati['delivery_zones_scope']?.toString() ?? 'restaurant';
        _chiusure = dati['closures'] as List<dynamic>? ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Chiusure ──────────────────────────────────────────────────────────────

  static String _hhmm(String? t) =>
      (t != null && t.length >= 5) ? t.substring(0, 5) : '';

  static String _dataIt(String iso) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  /// La chiusura copre questo momento?
  bool _chiusuraInCorso(Map<String, dynamic> c) {
    final adesso = DateTime.now();
    final oggi = DateFormat('yyyy-MM-dd').format(adesso);
    final inizio = c['date_start']?.toString() ?? '';
    final fine = c['date_end']?.toString() ?? '';
    if (inizio.compareTo(oggi) > 0 || fine.compareTo(oggi) < 0) return false;
    final ts = c['time_start']?.toString();
    final te = c['time_end']?.toString();
    if (ts == null || te == null) return true;
    final ora = DateFormat('HH:mm:ss').format(adesso);
    return ts.compareTo(ora) <= 0 && ora.compareTo(te) < 0;
  }

  String _descriviChiusura(Map<String, dynamic> c) {
    final unGiorno = c['date_start'] == c['date_end'];
    final quando = unGiorno
        ? _dataIt(c['date_start'].toString())
        : 'dal ${_dataIt(c['date_start'].toString())} '
              'al ${_dataIt(c['date_end'].toString())}';
    final ts = c['time_start']?.toString();
    final te = c['time_end']?.toString();
    if (ts == null || te == null) {
      return unGiorno ? '$quando, tutto il giorno' : '$quando, giorni interi';
    }
    return '$quando, dalle ${_hhmm(ts)} alle ${_hhmm(te)}';
  }

  Future<void> _annullaChiusura(Map<String, dynamic> c) async {
    final inCorso = _chiusuraInCorso(c);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inCorso ? 'Riaprire ora?' : 'Annullare la chiusura?'),
        content: Text(_descriviChiusura(c)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(inCorso ? 'Riapri ora' : 'Annulla chiusura'),
          ),
        ],
      ),
    );
    if (conferma != true) return;

    try {
      final aggiornate = await _service.deleteClosure(c['id'] as int);
      if (!mounted) return;
      setState(() => _chiusure = aggiornate);
      _messaggio(
        inCorso ? 'Ristorante riaperto' : 'Chiusura annullata',
        true,
      );
    } catch (e) {
      if (mounted) _messaggio(e.toString(), false);
    }
  }

  Future<void> _nuovaChiusura() async {
    final oggi = DateTime.now();
    var fasciaOraria = false;
    var dal = oggi;
    var al = oggi;
    TimeOfDay? dalle;
    TimeOfDay? alle;

    String fmtData(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
    String fmtOra(TimeOfDay? t) => t == null
        ? '--:--'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final salva = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          Future<void> scegliData(bool inizio) async {
            final scelta = await showDatePicker(
              context: ctx,
              initialDate: inizio ? dal : al,
              firstDate: oggi.subtract(const Duration(days: 1)),
              lastDate: oggi.add(const Duration(days: 365)),
            );
            if (scelta == null) return;
            setStateDialog(() {
              if (inizio) {
                dal = scelta;
                if (al.isBefore(dal)) al = dal;
              } else {
                al = scelta;
                if (al.isBefore(dal)) dal = al;
              }
            });
          }

          Future<void> scegliOra(bool inizio) async {
            final scelta = await showTimePicker(
              context: ctx,
              initialTime:
                  (inizio ? dalle : alle) ??
                  TimeOfDay(hour: TimeOfDay.now().hour, minute: 0),
            );
            if (scelta == null) return;
            setStateDialog(() {
              if (inizio) {
                dalle = scelta;
              } else {
                alle = scelta;
              }
            });
          }

          Widget rigaScelta(String etichetta, String valore, VoidCallback tap) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      etichetta,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: tap,
                      child: Text(
                        valore,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final fasciaIncompleta =
              fasciaOraria && (dalle == null || alle == null);
          final fasciaInvertita =
              fasciaOraria &&
              dalle != null &&
              alle != null &&
              (alle!.hour * 60 + alle!.minute) <=
                  (dalle!.hour * 60 + dalle!.minute);

          return AlertDialog(
            title: const Text('Chiudi il ristorante'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La chiusura ha sempre un inizio e una fine: '
                    'alla fine si riapre da soli.',
                    style: TextStyle(fontSize: 13, color: AppColors.gray),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Giorni interi')),
                      ButtonSegment(value: true, label: Text('Fascia oraria')),
                    ],
                    selected: {fasciaOraria},
                    onSelectionChanged: (sel) =>
                        setStateDialog(() => fasciaOraria = sel.first),
                  ),
                  const SizedBox(height: 16),
                  rigaScelta('Dal', fmtData(dal), () => scegliData(true)),
                  rigaScelta('Al', fmtData(al), () => scegliData(false)),
                  if (fasciaOraria) ...[
                    const SizedBox(height: 4),
                    rigaScelta('Dalle', fmtOra(dalle), () => scegliOra(true)),
                    rigaScelta('Alle', fmtOra(alle), () => scegliOra(false)),
                    if (fasciaInvertita)
                      const Text(
                        'L\'orario di fine deve essere dopo quello di inizio.',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: (fasciaIncompleta || fasciaInvertita)
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Chiudi ristorante'),
              ),
            ],
          );
        },
      ),
    );

    if (salva != true) return;

    String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    String? ora(TimeOfDay? t) => t == null
        ? null
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    try {
      final aggiornate = await _service.createClosure(
        dateStart: iso(dal),
        dateEnd: iso(al),
        timeStart: fasciaOraria ? ora(dalle) : null,
        timeEnd: fasciaOraria ? ora(alle) : null,
      );
      if (!mounted) return;
      setState(() => _chiusure = aggiornate);
      _messaggio('Chiusura salvata', true);
    } catch (e) {
      if (mounted) _messaggio(e.toString(), false);
    }
  }

  void _messaggio(String testo, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profilo ristorante')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errore != null
          ? _buildErrore()
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAnagrafica(),
                  const SizedBox(height: 16),
                  _buildChiusure(),
                  const SizedBox(height: 16),
                  _buildOrari(),
                  const SizedBox(height: 16),
                  _buildZone(),
                  const SizedBox(height: 16),
                  const Text(
                    'Per modificare orari di apertura e zone di consegna '
                    'usa il Pannello.',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: child,
    );
  }

  Widget _titoloSezione(IconData icona, String testo) {
    return Row(
      children: [
        Icon(icona, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          testo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAnagrafica() {
    final indirizzo = [
      _restaurant['address']?.toString() ?? '',
      _restaurant['city']?.toString() ?? '',
    ].where((s) => s.trim().isNotEmpty).join(', ');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _restaurant['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (indirizzo.isNotEmpty)
            _rigaInfo(Icons.location_on_outlined, indirizzo),
          if ((_restaurant['phone']?.toString() ?? '').isNotEmpty)
            _rigaInfo(Icons.phone_outlined, _restaurant['phone'].toString()),
          if ((_restaurant['email']?.toString() ?? '').isNotEmpty)
            _rigaInfo(Icons.mail_outline, _restaurant['email'].toString()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (_restaurant['delivery'] == 1)
                _chip('Consegna', AppColors.info),
              if (_restaurant['take_away'] == 1)
                _chip('Asporto', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rigaInfo(IconData icona, String testo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, size: 16, color: AppColors.gray),
          const SizedBox(width: 8),
          Expanded(child: Text(testo, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _chip(String testo, Color colore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        testo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colore,
        ),
      ),
    );
  }

  Widget _buildChiusure() {
    final inCorso = _chiusure
        .whereType<Map<String, dynamic>>()
        .where(_chiusuraInCorso)
        .toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titoloSezione(Icons.event_busy_outlined, 'Chiusure'),
          const SizedBox(height: 12),

          if (inCorso.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ORA CHIUSO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descriviChiusura(inCorso.first),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Nessuna chiusura in corso',
                    style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          ..._chiusure.whereType<Map<String, dynamic>>().map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _chiusuraInCorso(c)
                        ? Icons.do_not_disturb_on
                        : Icons.schedule,
                    size: 18,
                    color: _chiusuraInCorso(c)
                        ? AppColors.danger
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _descriviChiusura(c),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _annullaChiusura(c),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: Text(
                      _chiusuraInCorso(c) ? 'Riapri ora' : 'Annulla',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nuovaChiusura,
              icon: const Icon(Icons.event_busy, size: 20),
              label: const Text(
                'Chiudi il ristorante (dal-al)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrari() {
    // Raggruppa le fasce per giorno (0 = domenica come nel server)
    final perGiorno = <int, List<String>>{};
    for (final o in _orari.whereType<Map<String, dynamic>>()) {
      final giorno = int.tryParse(o['day_of_week']?.toString() ?? '') ?? -1;
      if (giorno < 0 || giorno > 6) continue;
      final inizio = _hhmm(o['start_time']?.toString());
      final fine = _hhmm(o['end_time']?.toString());
      if (inizio.isEmpty || fine.isEmpty) continue;
      perGiorno.putIfAbsent(giorno, () => []).add('$inizio-$fine');
    }

    // Ordine di lettura: lunedi' (1) .. domenica (0)
    final sequenza = [1, 2, 3, 4, 5, 6, 0];
    final oggi = DateTime.now().weekday % 7; // DateTime: lun=1..dom=7 -> dom=0

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titoloSezione(Icons.access_time, 'Orari di apertura'),
          const SizedBox(height: 12),
          ...sequenza.map((giorno) {
            final fasce = perGiorno[giorno];
            final eOggi = giorno == oggi;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      _giorni[giorno],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: eOggi ? FontWeight.bold : FontWeight.w500,
                        color: eOggi ? AppColors.primary : AppColors.dark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fasce == null || fasce.isEmpty
                          ? 'Chiuso'
                          : fasce.join('  '),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: eOggi ? FontWeight.bold : FontWeight.normal,
                        color: fasce == null || fasce.isEmpty
                            ? AppColors.gray
                            : AppColors.dark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildZone() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titoloSezione(Icons.delivery_dining_outlined, 'Costi di consegna'),
          if (_zoneScope == 'global')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Zone standard della piattaforma (nessuna zona dedicata)',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ),
          const SizedBox(height: 12),
          if (_zone.isEmpty)
            const Text(
              'Nessuna zona di consegna configurata',
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ..._zone.whereType<Map<String, dynamic>>().map((z) {
            double numero(dynamic v) =>
                double.tryParse(v?.toString() ?? '') ?? 0;
            final fee = numero(z['delivery_fee']);
            final minimo = numero(z['min_order']);
            final gratisDa = z['free_over'] != null
                ? numero(z['free_over'])
                : null;

            final dettagli = <String>[
              'Consegna EUR ${fee.toStringAsFixed(2)}',
              if (minimo > 0) 'Minimo EUR ${minimo.toStringAsFixed(2)}',
              if (gratisDa != null && gratisDa > 0)
                'Gratis da EUR ${gratisDa.toStringAsFixed(2)}',
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    z['name']?.toString() ?? 'Zona',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    dettagli.join('  ·  '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
