import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../models/address_model.dart';
import '../services/nominatim_service.dart';
import '../services/location_service.dart';
import '../services/address_service.dart';
import '../config/app_colors.dart';

/// Schermata per aggiungere o modificare un indirizzo
class AddAddressScreen extends StatefulWidget {
  final AddressModel? addressToEdit;

  const AddAddressScreen({super.key, this.addressToEdit});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasFieldKey = GlobalKey();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _aliasController = TextEditingController();
  final _scrollController = ScrollController();
  final _aliasFocusNode = FocusNode();

  final _nominatimService = NominatimService();
  final _locationService = LocationService();
  final _addressService = AddressService();

  String _selectedType = 'Casa';
  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.addressToEdit != null) {
      _populateForm(widget.addressToEdit!);
    }

    // Listener per auto-scroll quando il campo alias riceve il focus
    _aliasFocusNode.addListener(() {
      if (_aliasFocusNode.hasFocus) {
        _scrollToAliasField();
      }
    });
  }

  void _scrollToAliasField() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_scrollController.hasClients &&
          _aliasFieldKey.currentContext != null) {
        final RenderBox renderBox =
            _aliasFieldKey.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);

        // Calcola la posizione ottimale: campo appena sopra la tastiera
        final targetScroll = _scrollController.offset + position.dy - 100;

        _scrollController.animateTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _populateForm(AddressModel address) {
    _addressController.text = address.address;
    _cityController.text = address.city ?? '';
    _postalCodeController.text = address.postalCode ?? '';
    _aliasController.text = address.name ?? '';

    // Normalizza il tipo: mappa alias personalizzati ai tipi base
    final alias = address.aliasAddress.toLowerCase();
    if (alias.contains('casa') || alias.contains('home')) {
      _selectedType = 'Casa';
    } else if (alias.contains('lavoro') ||
        alias.contains('ufficio') ||
        alias.contains('work') ||
        alias.contains('office')) {
      _selectedType = 'Lavoro';
    } else {
      _selectedType = 'Altro';
    }
    _latitude = address.latitude;
    _longitude = address.longitude;
    _isDefault = address.isDefault;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _aliasController.dispose();
    _scrollController.dispose();
    _aliasFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Ottieni posizione corrente
      final position = await _locationService.getCurrentPosition();

      // Reverse geocoding per ottenere l'indirizzo
      final result = await _nominatimService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (result != null) {
        setState(() {
          // Usa indirizzo con numero civico se disponibile
          String fullAddress = '';
          if (result.road != null) {
            fullAddress = result.road!;
            if (result.houseNumber != null) {
              fullAddress += ' ${result.houseNumber}';
            }
          } else {
            fullAddress = result.displayName;
          }

          _addressController.text = fullAddress;
          _cityController.text = result.city ?? '';
          _postalCodeController.text = result.postcode ?? '';
          _latitude = result.coordinates.latitude;
          _longitude = result.coordinates.longitude;
        });
        _showSnackbar('Posizione rilevata con successo!', isError: false);
      } else {
        _showSnackbar('Impossibile determinare l\'indirizzo');
      }
    } on LocationServiceDisabledException catch (e) {
      _showSnackbar(e.message);
    } on LocationPermissionDeniedException catch (e) {
      _showSnackbar(e.message);
    } catch (e) {
      _showSnackbar('Errore nel rilevamento della posizione');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      _showSnackbar(
        'Seleziona un indirizzo dalla lista o usa la posizione corrente',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final address = AddressModel(
        id: widget.addressToEdit?.id,
        aliasAddress: _selectedType,
        name: _aliasController.text.isEmpty ? null : _aliasController.text,
        address: _addressController.text,
        city: _cityController.text.isEmpty ? null : _cityController.text,
        postalCode: _postalCodeController.text.isEmpty
            ? null
            : _postalCodeController.text,
        latitude: _latitude!,
        longitude: _longitude!,
        isDefault: _isDefault,
      );

      if (widget.addressToEdit == null) {
        // Nuovo indirizzo
        await _addressService.addAddress(address);
        _showSnackbar('Indirizzo aggiunto con successo!', isError: false);
      } else {
        // Modifica indirizzo esistente
        await _addressService.updateAddress(address);
        _showSnackbar('Indirizzo aggiornato con successo!', isError: false);
      }

      if (mounted) {
        Navigator.pop(context, true); // Ritorna true per indicare successo
      }
    } catch (e) {
      _showSnackbar('Errore: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Header con titolo e bottone chiudi
          _buildHeader(context),

          // Form scrollabile
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      28,
                      0,
                      28,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: _buildAddressForm(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
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
              Text(
                widget.addressToEdit == null
                    ? 'Nuovo Indirizzo'
                    : 'Modifica Indirizzo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
      ],
    );
  }

  Widget _buildAddressForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Autocomplete indirizzo
          TypeAheadField<NominatimResult>(
            controller: _addressController,
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: 'Indirizzo *',
                  labelStyle: const TextStyle(fontSize: 13),
                  hintText: 'Cerca via, piazza...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/icons/icons8-indirizzo-32.png',
                      width: 20,
                      height: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Image.asset(
                      'assets/icons/icons8-mirino-32.png',
                      width: 20,
                      height: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Usa posizione corrente',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            suggestionsCallback: (pattern) async {
              if (pattern.length < 3) return [];
              // Rispetta il limite di 1 req/sec di Nominatim
              await Future.delayed(const Duration(milliseconds: 1000));
              return await _nominatimService.searchAddress(pattern);
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.place, size: 20),
                title: Text(
                  suggestion.shortAddress,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  suggestion.displayName,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
            onSelected: (suggestion) {
              setState(() {
                // Usa indirizzo completo con civico se disponibile
                String fullAddress = '';
                if (suggestion.road != null) {
                  fullAddress = suggestion.road!;
                  if (suggestion.houseNumber != null) {
                    fullAddress += ', ${suggestion.houseNumber}';
                  }
                } else {
                  fullAddress = suggestion.displayName;
                }

                _addressController.text = fullAddress;
                _cityController.text = suggestion.city ?? '';
                _postalCodeController.text = suggestion.postcode ?? '';
                _latitude = suggestion.coordinates.latitude;
                _longitude = suggestion.coordinates.longitude;
              });
            },
            emptyBuilder: (context) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nessun risultato trovato',
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Città
          TextFormField(
            controller: _cityController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Castello',
              labelStyle: const TextStyle(fontSize: 13),
              hintText: 'Castello',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/icons/icons8-città-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.primary,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CAP
          TextFormField(
            controller: _postalCodeController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'CAP',
              labelStyle: const TextStyle(fontSize: 13),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/icons/icons8-cap-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.primary,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),

          // Tipo indirizzo
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Tipo',
              labelStyle: const TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'Casa',
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/icons8-casetta-32.png',
                      width: 20,
                      height: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Casa', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Lavoro',
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/icons8-ufficio2-32.png',
                      width: 20,
                      height: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Lavoro', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Altro',
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/icons8-mappa-32.png',
                      width: 20,
                      height: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Altro', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedType = value!);
            },
          ),

          const SizedBox(height: 16),

          // Alias personalizzato
          TextFormField(
            key: _aliasFieldKey,
            controller: _aliasController,
            focusNode: _aliasFocusNode,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Dai un nome a questo indirizzo',
              labelStyle: const TextStyle(fontSize: 13),
              hintText: 'Dai un nome a questo indirizzo',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/icons/icons8-carta-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.primary,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 1,
          ),

          const SizedBox(height: 16),

          // Checkbox predefinito
          CheckboxListTile(
            title: const Text(
              'Imposta come indirizzo predefinito',
              style: TextStyle(fontSize: 13),
            ),
            value: _isDefault,
            onChanged: (value) {
              setState(() => _isDefault = value ?? false);
            },
            activeColor: AppColors.primary,
          ),

          const SizedBox(height: 24),

          // Pulsante salva
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.dark,
                        ),
                      ),
                    )
                  : Text(
                      widget.addressToEdit == null
                          ? 'Aggiungi Indirizzo'
                          : 'Salva Modifiche',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
