/// Modello per le categorie dell'app (Spesa, Farmacia, ecc.)
class AppCategory {
  final int id;
  final String key;
  final String label;
  final String iconPath;
  final String actionType; // 'internal' | 'external'
  final String? actionValue;
  final bool isActive;
  final bool isComingSoon;
  final int displayOrder;

  AppCategory({
    required this.id,
    required this.key,
    required this.label,
    required this.iconPath,
    required this.actionType,
    this.actionValue,
    required this.isActive,
    required this.isComingSoon,
    required this.displayOrder,
  });

  /// Factory per creare un'istanza da JSON (API response)
  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] as int,
      key: json['key'] as String,
      label: json['label'] as String,
      iconPath: json['iconPath'] as String,
      actionType: json['actionType'] as String,
      actionValue: json['actionValue'] as String?,
      isActive: json['isActive'] as bool,
      isComingSoon: json['isComingSoon'] as bool,
      displayOrder: json['displayOrder'] as int,
    );
  }

  /// Converti in Map per serializzazione
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'label': label,
      'iconPath': iconPath,
      'actionType': actionType,
      'actionValue': actionValue,
      'isActive': isActive,
      'isComingSoon': isComingSoon,
      'displayOrder': displayOrder,
    };
  }

  @override
  String toString() {
    return 'AppCategory(id: $id, key: $key, label: $label, actionType: $actionType, isComingSoon: $isComingSoon)';
  }
}
