/// Modello per le cucine/categorie
class Cuisine {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int displayOrder;
  final String? icon;

  Cuisine({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.displayOrder,
    this.icon,
  });

  factory Cuisine.fromJson(Map<String, dynamic> json) {
    return Cuisine(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: (json['is_active'] as int?) == 1,
      displayOrder: json['display_order'] as int? ?? 0,
      icon: json['icon'] as String?,
    );
  }

  /// Ottiene il percorso dell'icona locale dalle assets
  /// Converte il nome della cucina nel nome file corrispondente
  String getIconAssetPath() {
    // Normalizza il nome per trovare il file corrispondente
    final normalized = name.toLowerCase().trim();

    // Mappa nomi cucine -> nomi file icone (nuovi nomi MAIUSCOLI con spazi)
    const iconMap = {
      'pizze': 'PIZZERIA',
      'pizza': 'PIZZERIA',
      'pizzeria': 'PIZZERIA',
      'italiana': 'ITALIANA',
      'italiano': 'ITALIANA',
      'giapponese': 'GIAPPONESE',
      'sushi': 'GIAPPONESE',
      'cinese': 'CINESE',
      'asiatica': 'CINESE',
      'fast food': 'FAST FOOD',
      'hamburger': 'FAST FOOD',
      'burger': 'FAST FOOD',
      'pasticceria': 'PASTICCERIA',
      'dolci': 'PASTICCERIA',
      'gelateria': 'GELATERIA',
      'gelato': 'GELATERIA',
      'gelati': 'GELATERIA',
      'vegana': 'VEGANA',
      'vegan': 'VEGANA',
      'vegetariana': 'VEGETARIANA',
      'vegetariano': 'VEGETARIANA',
      'gluten-free': 'GLUTEN FREE',
      'gluten free': 'GLUTEN FREE',
      'senza glutine': 'GLUTEN FREE',
      'etnica': 'ETNICA',
      'ethnic': 'ETNICA',
      'poke': 'POKE',
      'pokè': 'POKE',
      'poké': 'POKE',
      'tex-mex': 'TEX-MEX',
      'tex mex': 'TEX-MEX',
      'texmex': 'TEX-MEX',
      'messicana': 'TEX-MEX',
      'messicano': 'TEX-MEX',
      'mexicana': 'TEX-MEX',
    };

    final iconName = iconMap[normalized] ?? 'ITALIANA'; // Default fallback
    return 'assets/icons/$iconName.png';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'display_order': displayOrder,
      'icon': icon,
    };
  }
}
