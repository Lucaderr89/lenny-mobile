import 'package:flutter/material.dart';
import '../models/menu_item.dart';

/// Wheel Selector in stile iOS per la selezione di extra con molti elementi
/// Mostra 3-5 elementi alla volta con effetto sfumato e magnification centrale
class WheelExtraSelector extends StatefulWidget {
  final CustomizationGroup group;
  final Set<String> selectedIds;
  final Function(String optionId) onToggle;

  const WheelExtraSelector({
    super.key,
    required this.group,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  State<WheelExtraSelector> createState() => _WheelExtraSelectorState();
}

class _WheelExtraSelectorState extends State<WheelExtraSelector> {
  late FixedExtentScrollController _controller;
  int _currentIndex = 0;

  static const Color primaryColor = Color(0xFF0F4E8C);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color darkColor = Color(0xFF212121);
  static const Color grayColor = Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _getSelectionNumber(String optionId) {
    final selectedList = widget.selectedIds.toList();
    final index = selectedList.indexOf(optionId);
    return index >= 0 ? index + 1 : 0;
  }

  bool _canSelect() {
    if (widget.group.maxSelected == null) return true;
    return widget.selectedIds.length < widget.group.maxSelected!;
  }

  void _showSelectionPopup() {
    final selectedOptions = widget.group.options
        .where((option) => widget.selectedIds.contains(option.id))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titolo
                const Text(
                  'HAI SELEZIONATO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Griglia selezioni
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: selectedOptions.length,
                    itemBuilder: (context, index) {
                      final option = selectedOptions[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: successColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              option.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: darkColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (option.priceModifier != 0)
                              Text(
                                option.priceModifier > 0
                                    ? '+€${option.priceModifier.toStringAsFixed(2)}'
                                    : '€${option.priceModifier.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: grayColor,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Pulsante chiudi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'CHIUDI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con info selezione
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.group.maxSelected != null
                        ? 'Seleziona fino a ${widget.group.maxSelected} opzioni'
                        : 'Seleziona le opzioni che desideri',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                ),
                if (widget.selectedIds.isNotEmpty)
                  GestureDetector(
                    onTap: _showSelectionPopup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        'VEDI',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          decoration: TextDecoration.underline,
                          decorationColor: primaryColor,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Wheel Scroll View ORIZZONTALE
          SizedBox(
            height: 100,
            child: Stack(
              children: [
                // Indicatore centrale (bordo verticale per focus)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: primaryColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          right: BorderSide(
                            color: primaryColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Lista scrollabile ORIZZONTALE
                RotatedBox(
                  quarterTurns: 3,
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: 100,
                    diameterRatio: 2.0,
                    perspective: 0.003,
                    magnification: 1.0,
                    useMagnifier: false,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        if (index < 0 || index >= widget.group.options.length) {
                          return null;
                        }

                        final option = widget.group.options[index];
                        final isSelected = widget.selectedIds.contains(
                          option.id,
                        );
                        final isCurrent = index == _currentIndex;
                        final selectionNumber = _getSelectionNumber(option.id);
                        final distance = (index - _currentIndex).abs();

                        // Calcola opacity - mostra solo 2 elementi per lato
                        double opacity = 1.0;
                        if (distance == 1) {
                          opacity = 0.5;
                        } else if (distance >= 2) {
                          opacity = 0.2;
                        }

                        return RotatedBox(
                          quarterTurns: 1,
                          child: _buildExtraItem(
                            option,
                            isSelected,
                            isCurrent,
                            selectionNumber,
                            opacity,
                          ),
                        );
                      },
                      childCount: widget.group.options.length,
                    ),
                  ),
                ),

                // Gradient fade LEFT
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Gradient fade RIGHT
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer con istruzioni e tap per selezionare
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 16, color: grayColor),
                const SizedBox(width: 6),
                Text(
                  'Tap sull\'elemento centrale per selezionare',
                  style: TextStyle(
                    fontSize: 11,
                    color: grayColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraItem(
    CustomizationOption option,
    bool isSelected,
    bool isCurrent,
    int selectionNumber,
    double opacity,
  ) {
    final canSelect = _canSelect();
    final isDisabled = !isSelected && !canSelect;

    return GestureDetector(
      onTap: () {
        if (isDisabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Puoi selezionare massimo ${widget.group.maxSelected} opzioni',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Se non è l'elemento centrale, scrolla verso di esso
        if (!isCurrent) {
          _controller.animateToItem(
            widget.group.options.indexOf(option),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          // Se è l'elemento centrale, toggle la selezione
          widget.onToggle(option.id);
        }
      },
      child: Opacity(
        opacity: isDisabled ? 0.3 : opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isCurrent && isSelected)
                ? successColor.withValues(alpha: 0.15)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nome opzione
              Text(
                option.label,
                style: TextStyle(
                  fontSize: isCurrent ? 11 : 10,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isDisabled
                      ? grayColor
                      : (isSelected ? successColor : darkColor),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Prezzo SEMPRE visibile
              if (option.priceModifier != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    option.priceModifier > 0
                        ? '+€${option.priceModifier.toStringAsFixed(2)}'
                        : '€${option.priceModifier.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isCurrent ? 11 : 10,
                      fontWeight: FontWeight.w600,
                      color: grayColor,
                    ),
                  ),
                ),

              // Check icon per selezione con Stack
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: successColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
