import 'package:intl/intl.dart';

/// Rappresenta un singolo slot disponibile o non disponibile
class TimeSlot {
  final String? start;
  final String? end;
  final bool available;
  final String? reason;

  TimeSlot({this.start, this.end, required this.available, this.reason});

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      start: json['start'] as String?,
      end: json['end'] as String?,
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'available': available,
    'reason': reason,
  };

  /// Converte start time in formato DateTime
  DateTime? get startTime {
    if (start == null) return null;
    try {
      final today = DateTime.now();
      final format = DateFormat('HH:mm');
      final dateTime = format.parse(start!);
      return DateTime(
        today.year,
        today.month,
        today.day,
        dateTime.hour,
        dateTime.minute,
      );
    } catch (e) {
      return null;
    }
  }

  /// Converte end time in formato DateTime
  DateTime? get endTime {
    if (end == null) return null;
    try {
      final today = DateTime.now();
      final format = DateFormat('HH:mm');
      final dateTime = format.parse(end!);
      return DateTime(
        today.year,
        today.month,
        today.day,
        dateTime.hour,
        dateTime.minute,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Rappresenta la disponibilità di un piatto
class DishAvailability {
  final int id;
  final String name;
  final int categoryId;
  final double price;
  final List<TimeSlot> availableSlots;

  DishAvailability({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.availableSlots,
  });

  factory DishAvailability.fromJson(Map<String, dynamic> json) {
    return DishAvailability(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['category_id'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      availableSlots:
          (json['available_slots'] as List<dynamic>?)
              ?.map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Verifica se il piatto è disponibile in una fascia oraria specifica
  bool isAvailableAt(DateTime dateTime) {
    return availableSlots.any(
      (slot) =>
          slot.available &&
          slot.startTime != null &&
          slot.endTime != null &&
          dateTime.isAfter(slot.startTime!) &&
          dateTime.isBefore(slot.endTime!),
    );
  }

  /// Restituisce il motivo di indisponibilità in una fascia oraria
  String? getUnavailabilityReason(DateTime dateTime) {
    final slot = availableSlots.firstWhere(
      (s) =>
          !s.available &&
          s.startTime != null &&
          s.endTime != null &&
          dateTime.isAfter(s.startTime!) &&
          dateTime.isBefore(s.endTime!),
      orElse: () => TimeSlot(available: true),
    );
    return slot.reason;
  }

  /// Restituisce il prossimo slot disponibile
  TimeSlot? getNextAvailableSlot() {
    final now = DateTime.now();
    try {
      return availableSlots.firstWhere(
        (slot) =>
            slot.available &&
            slot.endTime != null &&
            slot.endTime!.isAfter(now),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Rappresenta la disponibilità di una categoria
class CategoryAvailability {
  final int id;
  final String name;
  final List<TimeSlot> availableSlots;
  final List<DishAvailability>? dishes;

  CategoryAvailability({
    required this.id,
    required this.name,
    required this.availableSlots,
    this.dishes,
  });

  factory CategoryAvailability.fromJson(Map<String, dynamic> json) {
    return CategoryAvailability(
      id: json['id'] as int,
      name: json['name'] as String,
      availableSlots:
          (json['available_slots'] as List<dynamic>?)
              ?.map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
              .toList() ??
          [],
      dishes: (json['dishes'] as List<dynamic>?)
          ?.map(
            (dish) => DishAvailability.fromJson(dish as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Rappresenta la disponibilità di un ristorante
class RestaurantAvailability {
  final int id;
  final String name;
  final bool isOpen;
  final List<TimeSlot> availableSlots;

  RestaurantAvailability({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.availableSlots,
  });

  factory RestaurantAvailability.fromJson(Map<String, dynamic> json) {
    return RestaurantAvailability(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isOpen: json['is_open'] as bool? ?? false,
      availableSlots:
          (json['available_slots'] as List<dynamic>?)
              ?.map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Verifica se il ristorante è aperto in una fascia oraria specifica
  bool isOpenAt(DateTime dateTime) {
    if (!isOpen) return false;
    return availableSlots.any(
      (slot) =>
          slot.available &&
          slot.startTime != null &&
          slot.endTime != null &&
          dateTime.isAfter(slot.startTime!) &&
          dateTime.isBefore(slot.endTime!),
    );
  }

  /// Restituisce il prossimo slot disponibile
  TimeSlot? getNextAvailableSlot() {
    final now = DateTime.now();
    try {
      return availableSlots.firstWhere(
        (slot) =>
            slot.available &&
            slot.endTime != null &&
            slot.endTime!.isAfter(now),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Risposta completa della disponibilità per una data specifica
class AvailabilityData {
  final String date;
  final int dayOfWeek;
  final RestaurantAvailability restaurant;
  final List<CategoryAvailability>? categories;
  final List<DishAvailability>? dishes;

  AvailabilityData({
    required this.date,
    required this.dayOfWeek,
    required this.restaurant,
    this.categories,
    this.dishes,
  });

  factory AvailabilityData.fromJson(Map<String, dynamic> json) {
    return AvailabilityData(
      date: json['date'] as String,
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      restaurant: RestaurantAvailability.fromJson(
        json['restaurant'] as Map<String, dynamic>? ?? {},
      ),
      categories: (json['categories'] as List<dynamic>?)
          ?.map(
            (cat) => CategoryAvailability.fromJson(cat as Map<String, dynamic>),
          )
          .toList(),
      dishes: (json['dishes'] as List<dynamic>?)
          ?.map(
            (dish) => DishAvailability.fromJson(dish as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Restituisce il nome del giorno della settimana
  String get dayName {
    final days = [
      'Domenica',
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
    ];
    return days[dayOfWeek];
  }

  /// Verifica se un piatto specifico è disponibile
  bool isDishAvailable(int dishId) {
    if (categories != null) {
      for (final category in categories!) {
        if (category.dishes != null) {
          final dish = category.dishes!.firstWhere(
            (d) => d.id == dishId,
            orElse: () => DishAvailability(
              id: -1,
              name: '',
              categoryId: 0,
              price: 0,
              availableSlots: [],
            ),
          );
          if (dish.id == dishId) {
            return dish.availableSlots.any((slot) => slot.available);
          }
        }
      }
    }

    if (dishes != null) {
      final dish = dishes!.firstWhere(
        (d) => d.id == dishId,
        orElse: () => DishAvailability(
          id: -1,
          name: '',
          categoryId: 0,
          price: 0,
          availableSlots: [],
        ),
      );
      if (dish.id == dishId) {
        return dish.availableSlots.any((slot) => slot.available);
      }
    }

    return false;
  }

  /// Restituisce il piatto per ID
  DishAvailability? getDishById(int dishId) {
    if (categories != null) {
      for (final category in categories!) {
        if (category.dishes != null) {
          try {
            return category.dishes!.firstWhere((d) => d.id == dishId);
          } catch (e) {
            // Continua alla prossima categoria
          }
        }
      }
    }

    if (dishes != null) {
      try {
        return dishes!.firstWhere((d) => d.id == dishId);
      } catch (e) {
        // Non trovato
      }
    }

    return null;
  }
}
