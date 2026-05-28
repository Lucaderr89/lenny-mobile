import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../services/shift_service.dart';

/// ShiftsScreen — Mostra i turni reali del driver (da platform DB via API)
class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final ShiftService _shiftService = ShiftService();

  DateTime _weekStart = _currentWeekMonday();
  bool _isLoading = false;
  List<Map<String, String>> _shifts = [];

  static DateTime _currentWeekMonday() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(_weekStart);
      final to = DateFormat(
        'yyyy-MM-dd',
      ).format(_weekStart.add(const Duration(days: 6)));
      final data = await _shiftService.getShiftsRange(
        dateFrom: from,
        dateTo: to,
      );
      if (mounted) setState(() => _shifts = data);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadShifts();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadShifts();
  }

  /// Turni raggruppati per giorno (Map dateStr → List<shift>)
  Map<String, List<Map<String, String>>> get _byDay {
    final map = <String, List<Map<String, String>>>{};
    for (final s in _shifts) {
      final g = s['giorno'] ?? '';
      map.putIfAbsent(g, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final title =
        '${DateFormat('d MMM', 'it').format(_weekStart)} – ${DateFormat('d MMM yyyy', 'it').format(weekEnd)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'I tuoi turni',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Navigazione settimana
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _previousWeek,
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),

          // Contenuto
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 7,
                    itemBuilder: (ctx, i) {
                      final day = _weekStart.add(Duration(days: i));
                      final key = DateFormat('yyyy-MM-dd').format(day);
                      final dayShifts = _byDay[key] ?? [];
                      return _buildDayCard(day, dayShifts);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime day, List<Map<String, String>> dayShifts) {
    final isToday =
        DateFormat('yyyy-MM-dd').format(day) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayName = DateFormat('EEEE d', 'it').format(day);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.lightGray.withValues(alpha: 0.3),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary
                : AppColors.lightGray.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              day.day.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isToday ? Colors.white : AppColors.dark,
              ),
            ),
          ),
        ),
        title: Text(
          dayName.substring(0, 1).toUpperCase() + dayName.substring(1),
          style: TextStyle(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
            color: AppColors.dark,
          ),
        ),
        subtitle: dayShifts.isEmpty
            ? Text(
                'Nessun turno',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray.withValues(alpha: 0.7),
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dayShifts
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${s['ora_inizio']} – ${s['ora_fine']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 56,
              color: AppColors.gray.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nessun turno questa settimana',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I turni vengono assegnati dal responsabile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.gray.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
