import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/theme_controller.dart';
import '../services/tts_service.dart';
import 'guida_sicura_screen.dart';

/// SettingsScreen - Impostazioni driver (aspetto + cambio password)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Serve l'elenco delle voci installate per popolare il selettore.
    TtsService().init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showToast('Le password non corrispondono', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Implementare chiamata API per cambio password
      await Future.delayed(const Duration(seconds: 1)); // Simula chiamata API

      _showToast('Password modificata con successo', isError: false);

      // Pulisci i campi
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // Nascondi la tastiera
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showToast('Errore durante la modifica: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCardAspetto() {
    final controller = ThemeController();
    final temaScuro = Theme.of(context).brightness == Brightness.dark;

    Widget opzione(ModalitaTema valore, String titolo, String descrizione) {
      final selezionata = controller.modalita == valore;
      return InkWell(
        onTap: () async {
          await controller.impostaModalita(valore);
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selezionata
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 22,
                color: selezionata ? AppColors.primary : context.cTestoSec,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      descrizione,
                      style: TextStyle(
                        fontSize: 12,
                        color: temaScuro
                            ? AppColors.nightTextSecondary
                            : context.cTestoSec,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cCard,
        border: context.cBordoCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: context.cOmbra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(
                  Icons.brightness_6_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aspetto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          opzione(
            ModalitaTema.automatica,
            'Automatico',
            'Chiaro di giorno, scuro dal tramonto all\'alba',
          ),
          opzione(ModalitaTema.chiara, 'Sempre chiaro', 'Tema chiaro fisso'),
          opzione(
            ModalitaTema.scura,
            'Sempre scuro',
            'Tema notte fisso, pensato per il cruscotto',
          ),
        ],
      ),
    );
  }

  /// I nomi di sistema sono sigle tipo "it-it-x-kda-network": illeggibili.
  /// Se ne mostra la sostanza — quello che cambia davvero e' se la voce e'
  /// sintetizzata sul server (piu' umana) o sul telefono.
  String _etichettaVoce(String nome) {
    final n = nome.toLowerCase();
    final sigla = RegExp(r'x-([a-z]+)').firstMatch(n)?.group(1) ?? '';
    final variante = sigla.isEmpty ? '' : ' ${sigla.toUpperCase()}';
    if (n.contains('network')) return 'Italiana naturale$variante';
    if (n.contains('neural') || n.contains('wavenet')) {
      return 'Italiana neurale$variante';
    }
    if (n.contains('local')) return 'Italiana sul telefono$variante';
    return nome;
  }

  Widget _chipVelocita(String etichetta, double valore, TtsService tts) {
    final selezionata = (tts.velocita - valore).abs() < 0.001;
    return Expanded(
      child: InkWell(
        onTap: () async {
          await tts.impostaVelocita(valore);
          await tts.prova('Nuovo ordine. Fascia delle 19 e 30');
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selezionata
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selezionata ? AppColors.primary : context.cBordo,
              width: selezionata ? 1.6 : 1,
            ),
          ),
          child: Text(
            etichetta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selezionata ? AppColors.primary : context.cTestoSec,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardGuida() {
    final temaScuro = Theme.of(context).brightness == Brightness.dark;
    final tts = TtsService();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cCard,
        border: context.cBordoCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: context.cOmbra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(
                  Icons.volume_up_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Guida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: tts.abilitato,
            onChanged: (valore) async {
              await tts.impostaAbilitato(valore);
              if (valore) {
                tts.annuncia('Annunci vocali attivi');
              }
              if (mounted) setState(() {});
            },
            title: const Text(
              'Annunci vocali',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'I nuovi ordini vengono letti ad alta voce',
              style: TextStyle(
                fontSize: 12,
                color: temaScuro
                    ? AppColors.nightTextSecondary
                    : context.cTestoSec,
              ),
            ),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),

          // Velocita' e voce: si regolano solo ad annunci accesi, altrimenti
          // sono comandi che non fanno niente.
          if (tts.abilitato) ...[
            const SizedBox(height: 4),
            Text(
              'VELOCITA\'',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: context.cTestoSec,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _chipVelocita('Lenta', TtsService.velocitaLenta, tts),
                const SizedBox(width: 8),
                _chipVelocita('Normale', TtsService.velocitaNormale, tts),
                const SizedBox(width: 8),
                _chipVelocita('Svelta', TtsService.velocitaSvelta, tts),
              ],
            ),
            if (tts.vociItaliane.length > 1) ...[
              const SizedBox(height: 14),
              Text(
                'VOCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: context.cTestoSec,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: tts.nomeVoce,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: context.cTesto),
                items: [
                  for (final voce in tts.vociItaliane)
                    DropdownMenuItem(
                      value: voce['name'],
                      child: Text(
                        _etichettaVoce(voce['name'] ?? ''),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (nome) async {
                  if (nome == null) return;
                  final voce = tts.vociItaliane.firstWhere(
                    (v) => v['name'] == nome,
                  );
                  await tts.impostaVoce(voce);
                  await tts.prova('Nuovo ordine. Fascia delle 19 e 30');
                  if (mounted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    tts.prova('Nuovo ordine. Fascia delle 19 e 30'),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Prova la voce'),
              ),
            ),
          ],

          const Divider(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.headset_mic_outlined,
              color: AppColors.primary,
            ),
            title: const Text(
              'Guida sicura',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Come farti leggere anche WhatsApp dal telefono',
              style: TextStyle(
                fontSize: 12,
                color: temaScuro
                    ? AppColors.nightTextSecondary
                    : context.cTestoSec,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuidaSicuraScreen()),
            ),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: context.cSfondo,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Impostazioni',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card aspetto: tema automatico col sole (default) o fisso.
              _buildCardAspetto(),
              const SizedBox(height: 16),

              // Card guida: annunci vocali della Modalita' Guida
              _buildCardGuida(),
              const SizedBox(height: 16),

              // Card cambio password
              Container(
                padding: const EdgeInsets.all(20),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Cambio Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.cTesto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Password attuale
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Password attuale',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci la password attuale';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nuova password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Nuova password',
                        prefixIcon: const Icon(Icons.lock_open),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci la nuova password';
                        }
                        if (value.length < 6) {
                          return 'La password deve essere di almeno 6 caratteri';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Conferma password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Conferma password',
                        prefixIcon: const Icon(Icons.lock_open),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Conferma la nuova password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Le password non corrispondono';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'La password deve contenere almeno 6 caratteri',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bottone salva
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Cambia Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
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
