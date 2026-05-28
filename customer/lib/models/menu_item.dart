class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final List<String> badges;
  final bool hasAR;
  final double? originalPrice;
  final List<CustomizationGroup> customizations;
  final List<InfoItem> allergens;
  final List<InfoItem> dietaryOptions;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.badges = const [],
    this.hasAR = false,
    this.originalPrice,
    this.customizations = const [],
    this.allergens = const [],
    this.dietaryOptions = const [],
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'badges': badges,
      'has_ar': hasAR,
      'original_price': originalPrice,
      'customizations': customizations.map((c) => c.toJson()).toList(),
      'allergens': allergens.map((a) => a.toJson()).toList(),
      'dietary_options': dietaryOptions.map((d) => d.toJson()).toList(),
    };
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Supporta sia 'discounted_price' che 'original_price'
    double? originalPrice;
    if (json['discounted_price'] != null && json['discounted_price'] != 0) {
      originalPrice = (json['price'] as num).toDouble();
    } else if (json['original_price'] != null) {
      originalPrice = (json['original_price'] as num).toDouble();
    }

    // Gestisce badges
    List<String> badges = [];
    if (json['is_featured'] == true) badges.add('Consigliato');
    if (json['spiciness_level'] != null && json['spiciness_level'] > 0) {
      badges.add('Piccante');
    }
    if (json['extra_groups_count'] != null && json['extra_groups_count'] > 0) {
      badges.add('Personalizzabile');
    }

    return MenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: json['discounted_price'] != null && json['discounted_price'] != 0
          ? (json['discounted_price'] as num).toDouble()
          : (json['price'] as num).toDouble(),
      imageUrl: _extractImageUrl(json),
      category: json['category_name'] as String? ?? 'Altro',
      badges: badges,
      hasAR: json['has_ar'] as bool? ?? false,
      originalPrice: originalPrice,
      customizations:
          (json['customizations'] as List<dynamic>?)
              ?.map(
                (e) => CustomizationGroup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      allergens:
          (json['allergens'] as List<dynamic>?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dietaryOptions:
          (json['dietary_options'] as List<dynamic>?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Estrae l'URL dell'immagine dal JSON (supporta cover_image da API)
  static String? _extractImageUrl(Map<String, dynamic> json) {
    // Prova con cover_image (struttura API)
    if (json['cover_image'] != null && json['cover_image'] is Map) {
      final coverImage = json['cover_image'] as Map<String, dynamic>;
      // Usa 'url' se disponibile (URL Firebase), altrimenti 'file_path'
      return coverImage['url']?.toString() ??
          coverImage['file_path']?.toString();
    }

    // Fallback a image_url diretto
    return json['image_url'] as String?;
  }
}

class CustomizationGroup {
  final String id;
  final String title;
  final String? description;
  final String groupType;
  final bool isRequired;
  final bool isMultiSelect;
  final int minSelected;
  final int? maxSelected;
  final List<CustomizationOption> options;

  CustomizationGroup({
    required this.id,
    required this.title,
    this.description,
    this.groupType = 'add',
    required this.isRequired,
    required this.isMultiSelect,
    this.minSelected = 0,
    this.maxSelected,
    required this.options,
  });

  factory CustomizationGroup.fromJson(Map<String, dynamic> json) {
    return CustomizationGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      groupType: json['group_type'] as String? ?? 'add',
      isRequired: json['is_required'] as bool? ?? false,
      isMultiSelect: json['is_multi_select'] as bool? ?? false,
      minSelected: json['min_selected'] as int? ?? 0,
      maxSelected: json['max_selected'] as int?,
      options: (json['options'] as List<dynamic>)
          .map((e) => CustomizationOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'group_type': groupType,
      'is_required': isRequired,
      'is_multi_select': isMultiSelect,
      'min_selected': minSelected,
      'max_selected': maxSelected,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

class CustomizationOption {
  final String id;
  final String label;
  final double priceModifier;

  CustomizationOption({
    required this.id,
    required this.label,
    this.priceModifier = 0.0,
  });

  factory CustomizationOption.fromJson(Map<String, dynamic> json) {
    return CustomizationOption(
      id: json['id'] as String,
      label: json['label'] as String,
      priceModifier: (json['price_modifier'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'price_modifier': priceModifier};
  }
}

class InfoItem {
  final int id;
  final String name;
  final String? icon;

  InfoItem({required this.id, required this.name, this.icon});

  factory InfoItem.fromJson(Map<String, dynamic> json) {
    return InfoItem(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'icon': icon};
  }
}
