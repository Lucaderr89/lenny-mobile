import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';
import 'add_address_screen.dart';

/// Schermata per visualizzare e gestire gli indirizzi salvati
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _addressService = AddressService();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final addresses = await _addressService.getAddresses();
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Errore caricamento indirizzi: $e');
      _showSnackbar('Errore nel caricamento degli indirizzi');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi eliminare l\'indirizzo "${address.address}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true && address.id != null) {
      try {
        await _addressService.deleteAddress(address.id!);
        _showSnackbar('Indirizzo eliminato', isError: false);
        _loadAddresses(); // Ricarica lista
      } catch (e) {
        _showSnackbar('Errore nell\'eliminazione: ${e.toString()}');
      }
    }
  }

  Future<void> _setDefaultAddress(AddressModel address) async {
    if (address.id == null) return;

    try {
      await _addressService.setDefaultAddress(address.id!);
      _showSnackbar('Indirizzo predefinito aggiornato', isError: false);
      _loadAddresses(); // Ricarica lista
    } catch (e) {
      _showSnackbar('Errore: ${e.toString()}');
    }
  }

  Future<void> _navigateToAddAddress([AddressModel? address]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: AddAddressScreen(addressToEdit: address),
      ),
    );

    if (result == true) {
      _loadAddresses(); // Ricarica se è stato salvato
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getAddressIconPath(AddressModel address) {
    final alias = address.aliasAddress.toLowerCase();
    if (alias.contains('casa') || alias.contains('home')) {
      return 'assets/icons/icons8-casetta-32.png';
    } else if (alias.contains('lavoro') ||
        alias.contains('ufficio') ||
        alias.contains('work') ||
        alias.contains('office')) {
      return 'assets/icons/icons8-ufficio2-32.png';
    } else {
      return 'assets/icons/icons8-mappa-32.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'I miei indirizzi',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? _buildEmptyState()
          : _buildAddressList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddAddress(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Nessun indirizzo salvato',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggiungi il tuo primo indirizzo!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final address = _addresses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: address.isDefault
                  ? AppColors.primary
                  : AppColors.grayLight,
              width: address.isDefault ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToAddAddress(address),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          _getAddressIconPath(address),
                          width: 22,
                          height: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    address.address,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (address.isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PREDEFINITO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (address.name != null &&
                                address.name!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFD042,
                                  ).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFFD042),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  address.name!,
                                  style: const TextStyle(
                                    color: AppColors.dark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${address.city ?? ""}, ${address.postalCode ?? ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (address.note != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                address.note!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 130,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 0,
                        children: [
                          if (!address.isDefault)
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: Tooltip(
                                message: 'Predefinito',
                                child: IconButton(
                                  onPressed: () => _setDefaultAddress(address),
                                  icon: const Icon(Icons.star_border),
                                  color: AppColors.primary,
                                  iconSize: 18,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Modifica',
                              child: IconButton(
                                onPressed: () => _navigateToAddAddress(address),
                                icon: const Icon(Icons.edit),
                                color: AppColors.primary,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Elimina',
                              child: IconButton(
                                onPressed: () => _deleteAddress(address),
                                icon: const Icon(Icons.delete),
                                color: AppColors.danger,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
