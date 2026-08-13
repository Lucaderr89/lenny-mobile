import 'package:flutter/material.dart';
import '../widgets/app_icon.dart';
import '../config/app_colors.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/favorites_provider.dart';
import '../widgets/wheel_extra_selector.dart';
import '../widgets/foto_rete.dart';

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
  static const Color primaryLight = AppColors.primaryLight;
  static const Color successColor = AppColors.success;
  static const Color dangerColor = AppColors.danger;
  static const Color warningColor = AppColors.warning;
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
      // Preselezione dei gruppi obbligatori a scelta singola SOLO se la
      // prima opzione costa zero: preselezionare un'opzione con sovrapprezzo
      // significherebbe addebitarla senza che l'utente abbia scelto nulla.
      for (var group in widget.menuItem.customizations) {
        if (group.isRequired &&
            !group.isMultiSelect &&
            group.options.isNotEmpty &&
            group.options.first.priceModifier == 0) {
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

  /// Piatto marcato "Non disponibile oggi" dal server: l'etichetta inizia
  /// con "non disponibile" (convenzione condivisa con la lista del menu).
  /// In quel caso l'aggiunta e' bloccata, non solo segnalata.
  bool get _isUnavailable {
    final label = widget.menuItem.availabilityLabel;
    return label != null && label.toLowerCase().startsWith('non disponibile');
  }

  /// Scelte che contano verso i limiti complessivi del piatto.
  ///
  /// Il pannello lo definisce come "elementi selezionati sommando tutti i
  /// gruppi": conta quindi sia le scelte multiple sia quelle singole. Restano
  /// fuori solo i gruppi con "Escludi dal limite totale", pensati per le
  /// opzioni che non sono gusti (il formato della vaschetta, il tipo di cono).
  int _scelteContate() {
    var totale = 0;
    for (final group in widget.menuItem.customizations) {
      if (group.excludedFromTotal) continue;
      if (group.isMultiSelect) {
        totale += _selectedExtras
            .where((extraId) => group.options.any((o) => o.id == extraId))
            .length;
      } else if (_selectedOptions.containsKey(group.id)) {
        totale += 1;
      }
    }
    return totale;
  }

  /// Quante scelte mancano al minimo complessivo, 0 se e' gia' soddisfatto.
  int _scelteMancanti() {
    final minimo = widget.menuItem.minTotalExtras;
    if (minimo == null) return 0;
    final mancanti = minimo - _scelteContate();
    return mancanti > 0 ? mancanti : 0;
  }

  bool _canAddToCart() {
    // Piatto non disponibile: mai aggiungibile, qualunque cosa sia selezionata
    if (_isUnavailable) return false;

    for (var group in widget.menuItem.customizations) {
      final selectedCount = group.isMultiSelect
          ? _selectedExtras
                .where((extraId) => group.options.any((o) => o.id == extraId))
                .length
          : (_selectedOptions.containsKey(group.id) ? 1 : 0);

      if (group.isRequired) {
        if (group.isMultiSelect) {
          if (selectedCount < group.minSelected) return false;
        } else {
          if (selectedCount == 0) return false;
        }
      } else if (selectedCount > 0 && selectedCount < group.minSelected) {
        // Gruppo facoltativo con un minimo: si puo' lasciarlo intatto, ma se
        // si comincia a scegliere bisogna arrivare al minimo. Prima non veniva
        // controllato affatto e il minimo dei gruppi non obbligatori era
        // semplicemente ignorato.
        return false;
      }

      if (group.maxSelected != null && selectedCount > group.maxSelected!) {
        return false;
      }
    }

    // Limiti complessivi del piatto, che valgono sopra i singoli gruppi.
    final totale = _scelteContate();
    final minimo = widget.menuItem.minTotalExtras;
    final massimo = widget.menuItem.maxTotalExtras;
    if (minimo != null && totale < minimo) return false;
    if (massimo != null && totale > massimo) return false;

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

    // Anche su un gruppo facoltativo il minimo va rispettato, una volta che si
    // e' cominciato a scegliere.
    if (!group.isRequired &&
        selectedCount > 0 &&
        selectedCount < group.minSelected) {
      return 'Seleziona almeno ${group.minSelected} o nessuno';
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

    if (group.maxSelected != null &&
        _getSelectedCount(group) >= group.maxSelected!) {
      return false;
    }

    // Tetto complessivo del piatto: si applica solo ai gruppi a scelta
    // multipla, dove le scelte si sommano. Su un gruppo a scelta singola
    // sceglierne un'altra sostituisce la precedente e il totale non cresce,
    // quindi bloccarlo lascerebbe l'utente incastrato senza motivo.
    final massimo = widget.menuItem.maxTotalExtras;
    if (massimo != null &&
        !group.excludedFromTotal &&
        _scelteContate() >= massimo) {
      return false;
    }

    return true;
  }

  double _calculateModalHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Le stime sono in "pixel a scala testo 1.0": con il text scaling di
    // sistema attivo i testi crescono ma le stime no, e il contenuto
    // finiva tagliato. Si scala tutta la parte testuale con lo stesso
    // fattore del sistema.
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    // Parti fisse (non testuali)
    double fixedHeight = 90 + 50; // Immagine visibile (90) + spazio onda (50)
    double footerHeight = 120; // Altezza approssimativa del footer

    double textHeight = 100; // Titolo + prezzo

    // Aggiungi altezza per descrizione
    if (widget.menuItem.description.isNotEmpty) {
      textHeight += 60;
    }

    // Aggiungi altezza per allergeni/caratteristiche
    if (widget.menuItem.allergens.isNotEmpty ||
        widget.menuItem.dietaryOptions.isNotEmpty) {
      textHeight += 80;
    }

    // Aggiungi altezza per personalizzazioni
    if (widget.menuItem.customizations.isNotEmpty) {
      for (var group in widget.menuItem.customizations) {
        textHeight += 60; // header del gruppo
        final optionCount = group.options.length;
        textHeight += (optionCount * 50).clamp(0, 250); // max 250 per gruppo
      }
    }

    final contentHeight = fixedHeight + footerHeight + textHeight * textScale;

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
                    ? FotoRete(
                        widget.menuItem.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 200,
                          color: lightGrayColor,
                          child: const AppIcon(
                            'assets/icons_svg/icons8-ristorante-32.svg',
                            color: grayColor,
                            size: 60,
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: lightGrayColor,
                        child: const AppIcon(
                          'assets/icons_svg/icons8-ristorante-32.svg',
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
                                _buildRiepilogoLimiti(),
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
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: AppIcon(
                        isFavorite
                            ? 'assets/icons_svg/icons8-mi-piace-32.svg'
                            : 'assets/icons_svg/icons8-mi-piace-32.svg',
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
                      color: Colors.black.withValues(alpha: 0.2),
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
          // Gerarchia corretta: il NOME domina, il prezzo accompagna
          // (prima il prezzo a 22px sovrastava il nome a 18px).
          Text(
            widget.menuItem.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 4),
          // Prezzo con eventuale sconto: il barrato visto in lista
          // non deve sparire aprendo la scheda.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.menuItem.hasDiscount) ...[
                Text(
                  '€${widget.menuItem.originalPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: grayColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '€${widget.menuItem.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.menuItem.hasDiscount
                      ? AppColors.success
                      : primaryColor,
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 11,
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
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+$remainingCount',
                          style: TextStyle(
                            fontSize: 11,
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
                color: color.withValues(alpha: 0.05),
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
                      color: color.withValues(alpha: 0.2),
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
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
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

  /// Striscia in cima alle variazioni con i limiti complessivi del piatto.
  ///
  /// Serve perche' quei limiti valgono sopra i singoli gruppi: senza, l'utente
  /// scopre di aver sforato solo quando le opzioni smettono di rispondere, o
  /// quando il bottone "Aggiungi" resta spento senza spiegazione.
  Widget _buildRiepilogoLimiti() {
    final minimo = widget.menuItem.minTotalExtras;
    final massimo = widget.menuItem.maxTotalExtras;
    if (minimo == null && massimo == null) return const SizedBox.shrink();

    final totale = _scelteContate();
    final mancanti = _scelteMancanti();
    final pieno = massimo != null && totale >= massimo;

    final String testo;
    if (mancanti > 0) {
      testo = massimo != null
          ? 'Scegli da $minimo a $massimo elementi: ne manca${mancanti == 1 ? '' : 'no'} $mancanti'
          : 'Scegli almeno $minimo element${minimo == 1 ? 'o' : 'i'}: ne manca${mancanti == 1 ? '' : 'no'} $mancanti';
    } else if (massimo != null) {
      testo = pieno
          ? 'Hai scelto tutti i $massimo elementi disponibili'
          : 'Hai scelto $totale element${totale == 1 ? 'o' : 'i'} su $massimo';
    } else {
      testo = 'Hai scelto $totale element${totale == 1 ? 'o' : 'i'}';
    }

    // Ambra finche' manca qualcosa, verde quando la scelta e' valida: il
    // colore da' la risposta prima che l'utente legga la frase.
    final Color colore = mancanti > 0 ? warningColor : successColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colore.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(
            mancanti > 0
                ? 'assets/icons_svg/icons8-informazioni-32.svg'
                : 'assets/icons_svg/icons8-mi-piace-32.svg',
            size: 18,
            color: colore,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              testo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colore,
              ),
            ),
          ),
        ],
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
                    fontSize: 11,
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
                    style: const TextStyle(fontSize: 11, color: grayColor),
                  ),
                if (group.isRequired &&
                    group.minSelected > 0 &&
                    group.maxSelected != null)
                  const Text(
                    ' • ',
                    style: TextStyle(fontSize: 11, color: grayColor),
                  ),
                if (group.maxSelected != null)
                  Text(
                    'Max: ${group.maxSelected}',
                    style: const TextStyle(fontSize: 11, color: grayColor),
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
                        fontSize: 11,
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
                fontSize: 11,
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
              : (canSelect
                    ? lightGrayColor
                    : lightGrayColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.3)
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Messaggio errore se non si può aggiungere: piatto non disponibile
          // (prioritario) oppure gruppi obbligatori incompleti.
          if (!canAdd &&
              (_isUnavailable || missingRequirements.isNotEmpty)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dangerColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: dangerColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isUnavailable
                          ? (widget.menuItem.availabilityLabel ??
                                'Non disponibile oggi')
                          : missingRequirements,
                      style: const TextStyle(
                        fontSize: 11,
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
    // Il minimo complessivo del piatto viene prima dei singoli gruppi: e'
    // trasversale, e dire "completa Gusti" quando il vincolo e' "almeno 3
    // elementi in tutto" manderebbe l'utente a cercare la cosa sbagliata.
    final mancanti = _scelteMancanti();
    if (mancanti > 0) {
      return mancanti == 1
          ? 'Scegli ancora 1 elemento'
          : 'Scegli ancora $mancanti elementi';
    }

    final massimo = widget.menuItem.maxTotalExtras;
    if (massimo != null && _scelteContate() > massimo) {
      return 'Hai superato il limite di $massimo elementi';
    }

    final missing = <String>[];

    for (var group in widget.menuItem.customizations) {
      final selectedCount = group.isMultiSelect
          ? _selectedExtras
                .where((extraId) => group.options.any((o) => o.id == extraId))
                .length
          : (_selectedOptions.containsKey(group.id) ? 1 : 0);

      if (group.isRequired) {
        if (group.isMultiSelect) {
          if (selectedCount < group.minSelected) {
            missing.add('${group.title} (min ${group.minSelected})');
          }
        } else if (selectedCount == 0) {
          missing.add(group.title);
        }
      } else if (selectedCount > 0 && selectedCount < group.minSelected) {
        // Gruppo facoltativo lasciato a meta': o si completa, o si svuota.
        missing.add('${group.title} (min ${group.minSelected} o nessuno)');
      }

      if (group.maxSelected != null && selectedCount > group.maxSelected!) {
        missing.add('${group.title} (max ${group.maxSelected})');
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
