import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/favorites_provider.dart';
import '../widgets/wheel_extra_selector.dart';

/// Product Detail Modal - Modal a mezzo schermo per customizzazione completa del prodotto
class ProductDetailModal extends StatefulWidget {
  final MenuItem menuItem;
  final int restaurantId;
  final String restaurantName;
  final Function(MenuItem, int, Map<String, dynamic>, double) onAddToCart;
  final int? initialQuantity;
  final Map<String, dynamic>? initialCustomizations;
  final bool isEditMode;

  const ProductDetailModal({
    super.key,
    required this.menuItem,
    required this.restaurantId,
    required this.restaurantName,
    required this.onAddToCart,
    this.initialQuantity,
    this.initialCustomizations,
    this.isEditMode = false,
  });

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal> {
  int _quantity = 1;
  final Map<String, String> _selectedOptions = {};
  final Set<String> _selectedExtras = {};
  final TextEditingController _instructionsController = TextEditingController();

  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = Color(0xFFFFB5A7);
  static const Color successColor = AppColors.success;
  static const Color dangerColor = AppColors.danger;
  static const Color darkColor = AppColors.dark;
  static const Color grayColor = AppColors.gray;
  static const Color lightGrayColor = AppColors.lightGray;

  @override
  void initState() {
    super.initState();

    // Set initial quantity if editing
    if (widget.initialQuantity != null) {
      _quantity = widget.initialQuantity!;
    }

    // Pre-populate customizations if editing
    if (widget.initialCustomizations != null) {
      // Gestisci options
      final options = widget.initialCustomizations?['options'];
      if (options != null && options is Map) {
        options.forEach((key, value) {
          _selectedOptions[key.toString()] = value.toString();
        });
      }

      // Gestisci extras - può essere una lista di stringhe o di oggetti
      final extras = widget.initialCustomizations?['extras'];
      if (extras != null && extras is List) {
        for (var extra in extras) {
          if (extra is String) {
            _selectedExtras.add(extra);
          } else if (extra is Map && extra.containsKey('id')) {
            _selectedExtras.add(extra['id'].toString());
          } else {
            _selectedExtras.add(extra.toString());
          }
        }
      }

      _instructionsController.text =
          widget.initialCustomizations?['instructions']?.toString() ?? '';
    } else {
      // Pre-select default options for required groups (only for new items)
      for (var group in widget.menuItem.customizations) {
        if (group.isRequired &&
            !group.isMultiSelect &&
            group.options.isNotEmpty) {
          _selectedOptions[group.id] = group.options.first.id;
        }
      }
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  double _calculateCustomizationsPriceModifier() {
    double modifier = 0.0;

    // Somma i priceModifier delle opzioni selezionate (single-select groups)
    for (var entry in _selectedOptions.entries) {
      final groupId = entry.key;
      final optionId = entry.value;

      // Trova il gruppo
      final group = widget.menuItem.customizations.firstWhere(
        (g) => g.id == groupId,
        orElse: () => CustomizationGroup(
          id: '',
          title: '',
          isRequired: false,
          isMultiSelect: false,
          options: [],
        ),
      );

      // Trova l'opzione selezionata nel gruppo
      final option = group.options.firstWhere(
        (o) => o.id == optionId,
        orElse: () => CustomizationOption(id: '', label: '', priceModifier: 0),
      );

      modifier += option.priceModifier;
    }

    // Somma i priceModifier degli extra selezionati (multi-select groups)
    for (var extraId in _selectedExtras) {
      // Trova il gruppo multi-select che contiene questo extra
      for (var group in widget.menuItem.customizations) {
        if (group.isMultiSelect) {
          final option = group.options.firstWhere(
            (o) => o.id == extraId,
            orElse: () =>
                CustomizationOption(id: '', label: '', priceModifier: 0),
          );
          if (option.id == extraId) {
            modifier += option.priceModifier;
            break; // Trovato, esci dal loop dei gruppi
          }
        }
      }
    }

    return modifier;
  }

  double _calculateTotalPrice() {
    double total =
        widget.menuItem.price + _calculateCustomizationsPriceModifier();
    return total * _quantity;
  }

  bool _canAddToCart() {
    // Check if all required groups have a selection
    for (var group in widget.menuItem.customizations) {
      if (group.isRequired) {
        if (group.isMultiSelect) {
          // Conta quanti extra sono selezionati per questo gruppo
          final selectedCount = _selectedExtras
              .where((extraId) => group.options.any((o) => o.id == extraId))
              .length;

          // Verifica minimo
          if (selectedCount < group.minSelected) {
            return false;
          }
        } else {
          // Single select: verifica se c'è una selezione
          if (!_selectedOptions.containsKey(group.id)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  String? _getGroupError(CustomizationGroup group) {
    if (!group.isMultiSelect) return null;

    final selectedCount = _selectedExtras
        .where((extraId) => group.options.any((o) => o.id == extraId))
        .length;

    if (group.isRequired && selectedCount < group.minSelected) {
      return 'Seleziona almeno ${group.minSelected}';
    }

    if (group.maxSelected != null && selectedCount > group.maxSelected!) {
      return 'Massimo ${group.maxSelected} selezionabili';
    }

    return null;
  }

  int _getSelectedCount(CustomizationGroup group) {
    if (!group.isMultiSelect) return 0;
    return _selectedExtras
        .where((extraId) => group.options.any((o) => o.id == extraId))
        .length;
  }

  bool _canSelectMore(CustomizationGroup group) {
    if (!group.isMultiSelect) return true;
    if (group.maxSelected == null) return true;
    return _getSelectedCount(group) < group.maxSelected!;
  }

  double _calculateModalHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Parti fisse
    double fixedHeight = 90 + 50; // Immagine visibile (90) + spazio onda (50)
    double footerHeight = 120; // Altezza approssimativa del footer
    double productInfoBaseHeight = 100; // Titolo + prezzo

    double contentHeight = fixedHeight + footerHeight + productInfoBaseHeight;

    // Aggiungi altezza per descrizione
    if (widget.menuItem.description.isNotEmpty) {
      // Stima circa 60px per la descrizione
      contentHeight += 60;
    }

    // Aggiungi altezza per allergeni/caratteristiche
    if (widget.menuItem.allergens.isNotEmpty ||
        widget.menuItem.dietaryOptions.isNotEmpty) {
      contentHeight += 80;
    }

    // Aggiungi altezza per personalizzazioni
    if (widget.menuItem.customizations.isNotEmpty) {
      for (var group in widget.menuItem.customizations) {
        // Circa 60px per l'header del gruppo
        contentHeight += 60;
        // Circa 50px per ogni opzione (stima media)
        int optionCount = group.options.length;
        contentHeight += (optionCount * 50).clamp(
          0,
          250,
        ); // Max 250px per gruppo
      }
    }

    // Limita tra un minimo e il massimo (90% dello schermo)
    return contentHeight.clamp(400, screenHeight * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = _calculateModalHeight(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: modalHeight,
        child: Stack(
          children: [
            // Immagine di copertina FISSA in alto
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 200,
                child: widget.menuItem.imageUrl != null
                    ? Image.network(
                        widget.menuItem.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 200,
                          color: lightGrayColor,
                          child: const Icon(
                            Icons.restaurant,
                            color: grayColor,
                            size: 60,
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: lightGrayColor,
                        child: const Icon(
                          Icons.restaurant,
                          color: grayColor,
                          size: 60,
                        ),
                      ),
              ),
            ),
            // Contenitore principale con onda
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: _ProductWaveClipper(),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 50), // Spazio ridotto per l'onda
                      // Contenuto scrollabile
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProductInfo(),
                              if (widget.menuItem.allergens.isNotEmpty ||
                                  widget.menuItem.dietaryOptions.isNotEmpty)
                                _buildAllergensAndDietary(),
                              if (widget
                                  .menuItem
                                  .customizations
                                  .isNotEmpty) ...[
                                ...widget.menuItem.customizations.map(
                                  (group) => _buildCustomizationGroup(group),
                                ),
                              ],
                              const SizedBox(height: 100), // Space for footer
                            ],
                          ),
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
            // Pulsante preferiti in alto a sinistra
            Positioned(
              top: 8,
              left: 8,
              child: Consumer<FavoritesProvider>(
                builder: (context, favProvider, child) {
                  final isFavorite = favProvider.isFavorite(
                    'dish',
                    widget.menuItem.id,
                  );
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? primaryColor : grayColor,
                      ),
                      onPressed: () {
                        if (isFavorite) {
                          favProvider.removeFavorite(
                            'dish',
                            widget.menuItem.id,
                          );
                        } else {
                          favProvider.addFavorite('dish', widget.menuItem.id);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            // Pulsante chiudi in evidenza
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.menuItem.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ),
              Text(
                '€${widget.menuItem.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          if (widget.menuItem.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.menuItem.description,
              style: const TextStyle(
                fontSize: 14,
                color: grayColor,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllergensAndDietary() {
    final hasAllergens = widget.menuItem.allergens.isNotEmpty;
    final hasDietary = widget.menuItem.dietaryOptions.isNotEmpty;

    if (!hasAllergens && !hasDietary) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lightGrayColor)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAllergens)
            _buildCompactInfoSection(
              'Allergeni',
              widget.menuItem.allergens,
              Icons.warning_amber_rounded,
              dangerColor,
            ),
          if (hasAllergens && hasDietary) const SizedBox(height: 10),
          if (hasDietary)
            _buildCompactInfoSection(
              'Caratteristiche',
              widget.menuItem.dietaryOptions,
              Icons.check_circle_outline,
              successColor,
            ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoSection(
    String title,
    List<InfoItem> items,
    IconData icon,
    Color color,
  ) {
    final maxVisible = title == 'Allergeni' ? 2 : 3;
    final hasMore = items.length > maxVisible;
    final visibleItems = hasMore ? items.take(maxVisible).toList() : items;
    final remainingCount = items.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...visibleItems.map((item) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
              if (hasMore)
                GestureDetector(
                  onTap: () => _showAllItems(title, items, icon, color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+$remainingCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 12, color: color),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllItems(
    String title,
    List<InfoItem> items,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: lightGrayColor)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items[index].name,
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationGroup(CustomizationGroup group) {
    final selectedCount = _getSelectedCount(group);
    final error = _getGroupError(group);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lightGrayColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con titolo e badge
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: group.isRequired ? dangerColor : grayColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  group.isRequired ? 'OBBLIGATORIO' : 'OPZIONALE',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          // Info selezione per multi-select
          if (group.isMultiSelect) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (group.isRequired && group.minSelected > 0)
                  Text(
                    'Min: ${group.minSelected}',
                    style: const TextStyle(fontSize: 10, color: grayColor),
                  ),
                if (group.isRequired &&
                    group.minSelected > 0 &&
                    group.maxSelected != null)
                  const Text(
                    ' • ',
                    style: TextStyle(fontSize: 10, color: grayColor),
                  ),
                if (group.maxSelected != null)
                  Text(
                    'Max: ${group.maxSelected}',
                    style: const TextStyle(fontSize: 10, color: grayColor),
                  ),
                const Spacer(),
                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: error != null ? dangerColor : primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedCount selezionati',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Messaggio di errore
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(
                fontSize: 10,
                color: dangerColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Usa Wheel Selector per gruppi multi-select con molti elementi (>6)
          if (group.isMultiSelect && group.options.length > 6)
            WheelExtraSelector(
              group: group,
              selectedIds: _selectedExtras,
              onToggle: (optionId) {
                setState(() {
                  if (_selectedExtras.contains(optionId)) {
                    _selectedExtras.remove(optionId);
                  } else if (_canSelectMore(group)) {
                    _selectedExtras.add(optionId);
                  }
                });
              },
            )
          else
            // Lista opzioni compatta per gruppi piccoli o single-select
            ...group.options.map(
              (option) => _buildCustomizationOption(group, option),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomizationOption(
    CustomizationGroup group,
    CustomizationOption option,
  ) {
    final isSelected = group.isMultiSelect
        ? _selectedExtras.contains(option.id)
        : _selectedOptions[group.id] == option.id;

    final canSelect = !isSelected && _canSelectMore(group);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (group.isMultiSelect) {
            if (_selectedExtras.contains(option.id)) {
              _selectedExtras.remove(option.id);
            } else if (canSelect) {
              _selectedExtras.add(option.id);
            }
          } else {
            _selectedOptions[group.id] = option.id;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryLight
              : (canSelect ? lightGrayColor : lightGrayColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (group.isMultiSelect)
              _buildCheckbox(isSelected)
            else
              _buildRadio(isSelected),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 12,
                  color: canSelect || isSelected ? darkColor : grayColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (option.priceModifier != 0)
              Text(
                '${option.priceModifier > 0 ? '+' : ''}€${option.priceModifier.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? primaryColor : grayColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(bool isSelected) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : grayColor,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isSelected ? primaryColor : grayColor,
          width: 1.5,
        ),
        color: isSelected ? primaryColor : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 10, color: Colors.white)
          : null,
    );
  }

  Widget _buildFooter() {
    final totalPrice = _calculateTotalPrice();
    final canAdd = _canAddToCart();
    final missingRequirements = _getMissingRequirements();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Messaggio errore se non si può aggiungere
          if (!canAdd && missingRequirements.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dangerColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: dangerColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      missingRequirements,
                      style: const TextStyle(
                        fontSize: 10,
                        color: dangerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quantità e bottone sulla stessa riga
          Row(
            children: [
              // Controlli quantità
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: lightGrayColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove,
                      onTap: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        _quantity.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                    ),
                    _buildQuantityButton(
                      icon: Icons.add,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Bottone aggiungi al carrello
              Expanded(
                child: ElevatedButton(
                  onPressed: canAdd
                      ? () async {
                          widget.onAddToCart(
                            widget.menuItem,
                            _quantity,
                            {
                              'options': _selectedOptions,
                              'extras': _selectedExtras.toList(),
                              'instructions': _instructionsController.text,
                            },
                            _calculateCustomizationsPriceModifier(),
                          );
                          if (!widget.isEditMode) {
                            Navigator.pop(context);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: grayColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.isEditMode
                        ? 'Modifica - €${totalPrice.toStringAsFixed(2)}'
                        : 'Aggiungi al carrello - €${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMissingRequirements() {
    final missing = <String>[];

    for (var group in widget.menuItem.customizations) {
      if (group.isRequired) {
        if (group.isMultiSelect) {
          final selectedCount = _selectedExtras
              .where((extraId) => group.options.any((o) => o.id == extraId))
              .length;

          if (selectedCount < group.minSelected) {
            missing.add('${group.title} (min ${group.minSelected})');
          }
        } else {
          if (!_selectedOptions.containsKey(group.id)) {
            missing.add(group.title);
          }
        }
      }
    }

    if (missing.isEmpty) return '';
    return 'Completa: ${missing.join(', ')}';
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? darkColor : grayColor,
        ),
      ),
    );
  }
}

/// CustomClipper per l'effetto onda nella parte superiore del modale prodotto
class _ProductWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Parte dall'alto con l'onda
    path.moveTo(0, 65);

    // Effetto onda nella parte superiore
    path.cubicTo(
      size.width * 0.15,
      57,
      size.width * 0.25,
      50,
      size.width * 0.35,
      55,
    );

    path.cubicTo(
      size.width * 0.5,
      60,
      size.width * 0.65,
      52,
      size.width * 0.75,
      56,
    );

    path.cubicTo(size.width * 0.85, 62, size.width * 0.95, 66, size.width, 65);

    // Completa il rettangolo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
