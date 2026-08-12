import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/location_provider.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../models/address_model.dart';
import '../screens/add_address_screen.dart';
import 'app_icon.dart';

/// Bottom sheet per selezionare indirizzo di consegna
class AddressSelectorBottomSheet extends StatefulWidget {
  const AddressSelectorBottomSheet({super.key});

  @override
  State<AddressSelectorBottomSheet> createState() =>
      _AddressSelectorBottomSheetState();
}

class _AddressSelectorBottomSheetState
    extends State<AddressSelectorBottomSheet> {
  final AddressService _addressService = AddressService();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;

  /// Un ospite non ha indirizzi salvati ne' puo' aggiungerne: gli si mostra
  /// solo la posizione del telefono, senza il pulsante che porterebbe a una
  /// schermata destinata a fallire al salvataggio.
  bool _loggato = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    final loggato = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (!loggato) {
      setState(() {
        _loggato = false;
        _addresses = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final addresses = await _addressService.getAddresses();
      if (!mounted) return;
      setState(() {
        _loggato = true;
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [ADDRESS SELECTOR] Errore caricamento indirizzi: $e');
      if (!mounted) return;
      setState(() {
        _loggato = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle drag
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scegli indirizzo di consegna',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildAddressList(),
          ),

          // Aggiungi indirizzo: solo con un account, perche' il salvataggio
          // avviene sul profilo. All'ospite si spiega invece perche' non c'e'.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loggato
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            builder: (context) => SizedBox(
                              height: MediaQuery.of(context).size.height * 0.80,
                              child: const AddAddressScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Aggiungi nuovo indirizzo',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      'Con un account puoi salvare i tuoi indirizzi e ritrovarli al prossimo ordine.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    final locationProvider = context.watch<LocationProvider>();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Posizione corrente
        _buildCurrentPositionTile(locationProvider),

        if (_addresses.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Indirizzi salvati',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),

          // Lista indirizzi salvati
          ..._addresses.map(
            (address) => _buildAddressTile(address, locationProvider),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentPositionTile(LocationProvider locationProvider) {
    final isSelected = locationProvider.isUsingCurrentPosition;
    final address =
        locationProvider.currentAddress ?? 'Rilevamento in corso...';
    final hasLocation = locationProvider.currentLatitude != null;

    return ListTile(
      leading: AppIcon(
        'assets/icons/icons8-codice-regione-32.png',
        width: 32,
        height: 32,
        color: AppColors.primary,
      ),
      title: Row(
        children: [
          Flexible(
            child: const Text(
              'Posizione',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Selezionato',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
      ),
      trailing: hasLocation
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icona modifica
                IconButton(
                  icon: const AppIcon(
                    'assets/icons_svg/icons8-modifica-32.svg',
                    size: 18,
                  ),
                  color: Colors.blue[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: () => _showEditAddressDialog(locationProvider),
                  tooltip: 'Modifica indirizzo',
                ),
                // Icona selezione
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.green[700] : Colors.grey,
                  size: 20,
                ),
              ],
            )
          : null,
      onTap: hasLocation
          ? () async {
              await locationProvider.useCurrentPosition();
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          : null,
    );
  }

  void _showEditAddressDialog(LocationProvider locationProvider) {
    final addressController = TextEditingController(
      text: locationProvider.currentAddress ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_location,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Modifica indirizzo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addressController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Inserisci l\'indirizzo corretto',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Annulla',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final newAddress = addressController.text.trim();
                        if (newAddress.isNotEmpty) {
                          locationProvider.updateCurrentAddress(newAddress);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Salva',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTile(
    AddressModel address,
    LocationProvider locationProvider,
  ) {
    final isSelected =
        !locationProvider.isUsingCurrentPosition &&
        locationProvider.selectedAddress?.id == address.id;

    // Se c'è un alias (name), mostra quello, altrimenti mostra aliasAddress
    final displayTitle = (address.name != null && address.name!.isNotEmpty)
        ? address.name!
        : address.aliasAddress;

    // Determina l'icona in base all'alias
    String iconPath;
    final alias = address.aliasAddress.toLowerCase();
    if (alias.contains('casa') || alias.contains('home')) {
      iconPath = 'assets/icons/icons8-casetta-32.png';
    } else if (alias.contains('lavoro') ||
        alias.contains('ufficio') ||
        alias.contains('work')) {
      iconPath = 'assets/icons/icons8-ufficio2-32.png';
    } else {
      iconPath = 'assets/icons/icons8-mappa-32.png'; // Altro
    }

    return ListTile(
      leading: AppIcon(iconPath, size: 32, color: AppColors.primary),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (address.isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Predefinito',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (isSelected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Selezionato',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address.formattedAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          if (address.city != null || address.postalCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (address.city != null) address.city,
                  if (address.postalCode != null) address.postalCode,
                ].join(' • '),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Colors.green[700])
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () {
        locationProvider.selectAddress(address);
        Navigator.pop(context);
      },
    );
  }
}

/// Helper per mostrare il bottom sheet
Future<void> showAddressSelectorBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) =>
          const AddressSelectorBottomSheet(),
    ),
  );
}
