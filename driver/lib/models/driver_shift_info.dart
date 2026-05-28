/// Risposta di GET /api/driver/shift/today
class DriverShiftInfo {
  final List<TodayShift> todayShifts;
  final NextShift? nextShift;
  final String availabilityStatus; // online / busy / offline
  final String date;

  DriverShiftInfo({
    required this.todayShifts,
    this.nextShift,
    required this.availabilityStatus,
    required this.date,
  });

  factory DriverShiftInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return DriverShiftInfo(
      todayShifts: (data['today_shifts'] as List<dynamic>? ?? [])
          .map((e) => TodayShift.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextShift: data['next_shift'] != null
          ? NextShift.fromJson(data['next_shift'] as Map<String, dynamic>)
          : null,
      availabilityStatus: data['availability_status'] as String? ?? 'offline',
      date: data['date'] as String? ?? '',
    );
  }

  bool get isOnline => availabilityStatus == 'online';
  bool get isBusy => availabilityStatus == 'busy';
  bool get isActive => isOnline || isBusy;
  bool get hasShiftToday => todayShifts.isNotEmpty;

  /// Turno attualmente in corso (ora_inizio <= now < ora_fine)
  TodayShift? get currentShift {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final s in todayShifts) {
      final start = _parseTime(todayStr, s.oraInizio);
      final end = _parseTime(todayStr, s.oraFine);
      if (start != null &&
          end != null &&
          now.isAfter(start) &&
          now.isBefore(end)) {
        return s;
      }
    }
    return null;
  }

  /// Prossima fascia futura di oggi (non ancora iniziata)
  TodayShift? get upcomingShiftToday {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final s in todayShifts) {
      final start = _parseTime(todayStr, s.oraInizio);
      if (start != null && now.isBefore(start)) return s;
    }
    return null;
  }

  static DateTime? _parseTime(String dateStr, String hhmm) {
    try {
      final parts = hhmm.split(':');
      final d = DateTime.parse(dateStr);
      return DateTime(
        d.year,
        d.month,
        d.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }
}

class TodayShift {
  final String oraInizio;
  final String oraFine;
  final String categoria;

  TodayShift({
    required this.oraInizio,
    required this.oraFine,
    required this.categoria,
  });

  factory TodayShift.fromJson(Map<String, dynamic> json) => TodayShift(
    oraInizio: json['ora_inizio'] as String,
    oraFine: json['ora_fine'] as String,
    categoria: json['categoria'] as String? ?? '',
  );
}

class NextShift {
  final String giorno;
  final String oraInizio;
  final String oraFine;
  final String categoria;

  NextShift({
    required this.giorno,
    required this.oraInizio,
    required this.oraFine,
    required this.categoria,
  });

  factory NextShift.fromJson(Map<String, dynamic> json) => NextShift(
    giorno: json['giorno'] as String,
    oraInizio: json['ora_inizio'] as String,
    oraFine: json['ora_fine'] as String,
    categoria: json['categoria'] as String? ?? '',
  );
}
