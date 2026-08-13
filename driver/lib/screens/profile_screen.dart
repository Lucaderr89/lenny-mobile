import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/driver_service.dart';
import '../services/driver_session_service.dart';
import 'shifts_screen.dart';
import 'delivery_history_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';
import '../services/auth_service.dart';

/// ProfileScreen per Driver
/// Visualizza dati registrazione (read-only) + modifica IBAN + upload documenti
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DriverService _driverService = DriverService();
  final DriverSessionService _sessionService = DriverSessionService();
  final TextEditingController _ibanController = TextEditingController();

  String _driverName = '';
  String _driverEmail = '';
  String _driverPhone = '';
  String _driverFiscalId = '';
  String _driverIban = '';
  String _driverAddress = '';
  String _driverCity = '';
  String _driverState = '';
  String _driverZip = '';
  String _documentPath = '';

  bool _isLoading = true;
  bool _isEditingIban = false;
  bool _isSavingIban = false;
  bool _isUploadingDoc = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _sessionService.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getInt(AppConstants.keyDriverId);

      if (driverId == null) {
        throw Exception('Driver ID non trovato');
      }

      // Carica dati driver dal backend
      final driverData = await _driverService.getDriverDetails(driverId);

      // Verifica sessione attiva
      final session = await _sessionService.fetchActiveSession();
      final isOnline = session != null && session.isActive;

      setState(() {
        _driverName = driverData['name'] ?? '';
        _driverEmail = driverData['email'] ?? '';
        _driverPhone = driverData['phone'] ?? '';
        _driverFiscalId = driverData['fiscal_id'] ?? '';
        _driverIban = driverData['iban'] ?? '';
        _driverAddress = driverData['address'] ?? '';
        _driverCity = driverData['city'] ?? '';
        _driverState = driverData['state'] ?? '';
        _driverZip = driverData['zip'] ?? '';
        _documentPath = driverData['document_path'] ?? '';
        _isOnline = isOnline;

        _ibanController.text = _driverIban;
      });
    } catch (e) {
      print('❌ Errore caricamento dati driver: $e');
      _showToast('Errore caricamento dati', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveIban() async {
    final newIban = _ibanController.text.trim();

    if (newIban.isEmpty) {
      _showToast('IBAN non può essere vuoto', isError: true);
      return;
    }

    setState(() => _isSavingIban = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getInt(AppConstants.keyDriverId);

      await _driverService.updateDriverIban(driverId!, newIban);

      setState(() {
        _driverIban = newIban;
        _isEditingIban = false;
      });

      _showToast('IBAN aggiornato con successo', isError: false);
    } catch (e) {
      print('❌ Errore salvataggio IBAN: $e');
      _showToast('Errore salvataggio IBAN', isError: true);
    } finally {
      setState(() => _isSavingIban = false);
    }
  }

  Future<void> _openDocument() async {
    if (_documentPath.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Immagine documento
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: context.cCard,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _documentPath,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          SizedBox(height: 8),
                          Text('Errore caricamento immagine'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottone chiudi
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
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

  Future<void> _uploadDocument() async {
    try {
      // Mostra dialog per scegliere tra fotocamera e galleria
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carica Documento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt,
                      color: AppColors.primary,
                    ),
                    title: const Text('Scatta foto'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: AppColors.primary,
                    ),
                    title: const Text('Scegli dalla galleria'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close, color: AppColors.danger),
                    title: const Text('Annulla'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Chiedi il nome del documento
      final TextEditingController docNameController = TextEditingController();
      final String? documentName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nome Documento'),
          content: TextField(
            controller: docNameController,
            decoration: const InputDecoration(
              labelText: 'Inserisci nome documento',
              hintText: 'es: Patente, Carta Identità, Assicurazione',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (docNameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, docNameController.text.trim());
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      );

      if (documentName == null || documentName.isEmpty) {
        return;
      }

      setState(() => _isUploadingDoc = true);

      // Upload su Firebase Storage
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getInt(AppConstants.keyDriverId);
      final fileName =
          'driver_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('driver_documents')
          .child(fileName);

      final file = File(image.path);
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Salva URL nel backend con il nome del documento
      await _driverService.addDriverDocument(
        driverId!,
        downloadUrl,
        documentName,
      );

      _showToast(
        'Documento "$documentName" caricato con successo',
        isError: false,
      );
    } catch (e) {
      print('❌ Errore upload documento: $e');
      _showToast('Errore caricamento documento', isError: true);
    } finally {
      setState(() => _isUploadingDoc = false);
    }
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.cSfondo,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Il mio Profilo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sezione Dati Personali
            _buildSectionCard(
              title: 'Dati Personali',
              icon: Icons.person,
              children: [
                _buildReadOnlyField('Nome', _driverName),
                _buildReadOnlyField('Email', _driverEmail),
                _buildReadOnlyField('Telefono', _driverPhone),
                _buildReadOnlyField('Codice ISS', _driverFiscalId),
              ],
            ),
            const SizedBox(height: 16),

            // Sezione Indirizzo
            _buildSectionCard(
              title: 'Indirizzo',
              icon: Icons.location_on,
              children: [
                _buildReadOnlyField('Via', _driverAddress),
                _buildReadOnlyField('Città', _driverCity),
                _buildReadOnlyField('Provincia', _driverState),
                _buildReadOnlyField('CAP', _driverZip),
              ],
            ),
            const SizedBox(height: 16),

            // Sezione IBAN (modificabile)
            _buildSectionCard(
              title: 'Dati Pagamento',
              icon: Icons.account_balance,
              children: [
                if (!_isEditingIban)
                  Row(
                    children: [
                      Expanded(child: _buildReadOnlyField('IBAN', _driverIban)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () {
                          setState(() => _isEditingIban = true);
                        },
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _ibanController,
                        decoration: const InputDecoration(
                          labelText: 'IBAN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingIban = false;
                                  _ibanController.text = _driverIban;
                                });
                              },
                              child: const Text('Annulla'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSavingIban ? null : _saveIban,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                              ),
                              child: _isSavingIban
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Salva'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Sezione Documenti
            _buildSectionCard(
              title: 'Documenti',
              icon: Icons.description,
              children: [
                if (_documentPath.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.cBordo.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Documento registrazione')),
                        IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            color: AppColors.primary,
                          ),
                          onPressed: _openDocument,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Nessun documento caricato',
                    style: TextStyle(color: context.cTestoSec),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingDoc ? null : _uploadDocument,
                    icon: _isUploadingDoc
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Carica Nuovo Documento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        border: context.cBordoCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.cTesto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.cTestoSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Non specificato' : value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: value.isEmpty ? context.cTestoSec : context.cTesto,
            ),
          ),
          const Divider(height: 16, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: context.cBordo,
        child: Column(
          children: [
            // Header Drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _driverName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.cSfondo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _driverEmail,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.cSfondo.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Turni/Disponibilità',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShiftsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Storico Consegne',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeliveryHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Impostazioni',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.support_agent,
                    title: 'Supporto',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    textColor: AppColors.danger,
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  ),

                  // Bottone Fine Turno evidenziato
                  if (_isOnline) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: _buildEndShiftButton(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.primary),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textColor ?? context.cTesto,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildEndShiftButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                _showEndShiftDialog();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.danger,
                      AppColors.danger.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sei Online',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap per finire il turno',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEndShiftDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 32,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 20),

              // Titolo
              Text(
                'Terminare il turno?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.cTesto,
                ),
              ),
              const SizedBox(height: 12),

              // Descrizione
              Text(
                'Non riceverai più ordini fino al prossimo turno.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.cTestoSec,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Bottoni su stessa riga
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: context.cTestoSec.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Annulla',
                        style: TextStyle(
                          color: context.cTestoSec,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _endShift();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Termina',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Future<void> _endShift() async {
    try {
      await _sessionService.endShift();
      setState(() => _isOnline = false);
      _showToast('Turno terminato 🏁', isError: false);
    } catch (e) {
      _showToast('Errore: $e', isError: true);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.cTestoSec.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.cTesto,
              ),
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              'Sei sicuro di voler uscire?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.cTestoSec),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.cTestoSec.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Annulla',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.cTesto,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Esci',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      // Come nel menu della home: si passa da AuthService.logout(), che
      // avvisa il server e fa cancellare il token FCM di questo telefono.
      await AuthService().logout();

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('❌ Errore logout: $e');
      _showToast('Errore durante il logout', isError: true);
    }
  }
}
