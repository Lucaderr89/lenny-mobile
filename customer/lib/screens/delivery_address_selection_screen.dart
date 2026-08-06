import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../widgets/wave_clipper.dart';
import '../providers/location_provider.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';
import 'add_address_screen.dart';
import '../widgets/app_icon.dart';

/// Schermata per selezionare l'indirizzo di consegna
class DeliveryAddressSelectionScreen extends StatefulWidget {
  const DeliveryAddressSelectionScreen({super.key});

  @override
  State<DeliveryAddressSelectionScreen> createState() =>
      _DeliveryAddressSelectionScreenState();
}

class _DeliveryAddressSelectionScreenState
    extends State<DeliveryAddressSelectionScreen> {
  final AddressService _addressService = AddressService();
  List<AddressModel> _savedAddresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    setState(() => _isLoading = true);
    try {
      final addresses = await _addressService.getAddresses();
      setState(() {
        _savedAddresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore caricamento indirizzi: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header con testo e immagine in stile login
              SizedBox(
                width: double.infinity,
                height: 140,
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      left: 20,
                      top: 10,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: AppIcon(
'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
                          width: 24,
                          height: 24,
                          color: AppColors.dark,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    // Testo a sinistra
                    Positioned(
                      left: 28,
                      top: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dove\nconsegniamo?',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Immagine a destra
                    Positioned(
                      right: -10,
                      bottom: -40,
                      child: Image.asset(
                        'assets/images/RICEVI.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // Card bianca con opzioni e bordo ondulato
              ClipPath(
                clipper: const WaveClipper(),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height
                        - 140
                        - MediaQuery.of(context).padding.top
                        + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: MediaQuery.of(context).size.height - 140,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(20, 110, 20, 40 + MediaQuery.of(context).padding.bottom),
                          child: Column(
                            children: [
                              // Opzione: Posizione corrente
                              _AddressOptionCard(
                                iconPath: 'assets/icons/icons8-mirino-32.png',
                                title: 'Usa posizione corrente',
                                subtitle: 'Useremo il GPS del tuo dispositivo',
                                iconColor: AppColors.primary,
                                onTap: () => _useCurrentPosition(),
                              ),

                              const SizedBox(height: 16),

                              // Indirizzi salvati
                              if (_savedAddresses.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'I tuoi indirizzi salvati',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.grayDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._savedAddresses.map(
                                  (address) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SavedAddressCard(
                                      address: address,
                                      onTap: () => _useSavedAddress(address),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Aggiungi nuovo indirizzo
                              _AddressOptionCard(
                                iconPath: 'assets/icons/icons8-mappa-32.png',
                                title: 'Aggiungi nuovo indirizzo',
                                subtitle:
                                    'Salva un indirizzo per riutilizzarlo',
                                iconColor: AppColors.accent,
                                textColor: AppColors.dark,
                                onTap: () => _addNewAddress(),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Usa posizione corrente
  void _useCurrentPosition() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    // Richiedi posizione GPS
    final success = await locationProvider.requestCurrentPosition();

    // Chiudi loading
    if (mounted) Navigator.pop(context);

    if (success) {
      // Imposta tipo ordine a delivery
      locationProvider.setOrderType('delivery');

      // Torna indietro con successo
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      // Errore
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile ottenere la posizione GPS',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Usa indirizzo salvato
  void _useSavedAddress(AddressModel address) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Seleziona l'indirizzo
    locationProvider.selectAddress(address);
    locationProvider.setOrderType('delivery');

    // Torna indietro con successo
    Navigator.pop(context, true);
  }

  /// Aggiungi nuovo indirizzo
  void _addNewAddress() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const AddAddressScreen(),
      ),
    );

    if (result == true) {
      // Ricarica lista indirizzi
      _loadSavedAddresses();
    }
  }
}

/// Card per opzione indirizzo
class _AddressOptionCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _AddressOptionCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.textColor = AppColors.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grayLight, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  iconPath,
                  width: 22,
                  height: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.grayDark,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withValues(alpha: 0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card per indirizzo salvato
class _SavedAddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onTap;

  const _SavedAddressCard({required this.address, required this.onTap});

  String _getAddressIconPath() {
    switch (address.aliasAddress.toLowerCase()) {
      case 'casa':
        return 'assets/icons/icons8-casetta-32.png';
      case 'lavoro':
      case 'ufficio':
        return 'assets/icons/icons8-ufficio2-32.png';
      default:
        return 'assets/icons/icons8-mappa-32.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  _getAddressIconPath(),
                  width: 22,
                  height: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.name != null && address.name!.isNotEmpty
                          ? address.name!
                          : address.aliasAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.formattedAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.grayDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

