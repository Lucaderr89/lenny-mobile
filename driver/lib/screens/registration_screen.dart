import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';

/// Screen registrazione driver
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ibanController = TextEditingController();
  final _issCodeController = TextEditingController();

  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? _documentImage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ibanController.dispose();
    _issCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
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

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _documentImage = File(image.path);
        });
        _showToast('Documento caricato', isError: false);
      }
    } catch (e) {
      _showToast('Errore nel caricamento del documento: $e', isError: true);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Documento non più obbligatorio - rimosso controllo
    // if (_documentImage == null) {
    //   _showToast('Carica un documento di identità', isError: true);
    //   return;
    // }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showToast('Le password non coincidono', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        iban: _ibanController.text.trim(),
        issCode: _issCodeController.text.trim(),
        documentImage: _documentImage, // Opzionale
      );

      if (!mounted) return;

      if (response.success) {
        _showToast(
          'Registrazione completata! In attesa di approvazione.',
          isError: false,
        );
        // Torna al login
        Navigator.of(context).pop();
      } else {
        _showToast(response.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showToast('Errore durante la registrazione: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Registrazione Driver'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Dati Personali'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _firstNameController,
                    label: 'Nome',
                    icon: Icons.person_outline,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Inserisci il nome' : null,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Cognome',
                    icon: Icons.person_outline,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Inserisci il cognome' : null,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Inserisci l\'email';
                      if (!value!.contains('@')) return 'Email non valida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Telefono',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Inserisci il telefono';
                      }
                      if (value!.length < 10) {
                        return 'Numero non valido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Sicurezza'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Inserisci la password';
                      }
                      if (value!.length < AppConstants.minPasswordLength) {
                        return 'Minimo ${AppConstants.minPasswordLength} caratteri';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Conferma Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Conferma la password';
                      }
                      if (value != _passwordController.text) {
                        return 'Le password non coincidono';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Informazioni Pagamento'),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _ibanController,
                    label: 'IBAN',
                    icon: Icons.account_balance_outlined,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Inserisci l\'IBAN';
                      }
                      if (value!.length < 15) {
                        return 'IBAN non valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _issCodeController,
                    label: 'Codice ISS',
                    icon: Icons.credit_card_outlined,
                    helperText: 'Se non disponibile, inserisci: 00000',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Inserisci il codice ISS (o 00000)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Documento di Identità (opzionale)'),
                  const SizedBox(height: 8),
                  Text(
                    'Puoi caricare il documento ora o successivamente',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                  const SizedBox(height: 16),

                  _buildDocumentUpload(),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Completa Registrazione'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      // Come nel login: la card ha colori chiari fissi, quindi il testo non
      // puo' ereditare il colore dal tema, che di notte passa allo scuro.
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: TextStyle(fontSize: 11, color: AppColors.gray),
      ),
      validator: validator,
    );
  }

  Widget _buildDocumentUpload() {
    return InkWell(
      onTap: _pickDocument,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: _documentImage != null
                ? AppColors.success
                : AppColors.lightGray,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
        ),
        child: _documentImage != null
            ? Stack(
                children: [
                  // Anteprima documento
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _documentImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Overlay con badge e pulsante elimina
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Caricato',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Pulsante elimina
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _documentImage = null;
                          });
                          _showToast('Documento rimosso', isError: false);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Testo "Tocca per cambiare" in basso
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tocca per cambiare documento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.upload_file, color: AppColors.gray, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Carica Documento',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tocca per selezionare',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                ],
              ),
      ),
    );
  }
}
