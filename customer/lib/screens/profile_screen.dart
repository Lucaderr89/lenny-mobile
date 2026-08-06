import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import 'addresses_screen.dart';
import 'loyalty_screen.dart';
import 'order_history_screen.dart';
import 'support_screen.dart';
import 'wallet_screen.dart';
import '../widgets/app_icon.dart';

/// Profilo a LISTA PIATTA: account in alto, voci sotto, tutto visibile.
///
/// Prima questa pagina era in realta' la pagina loyalty (due tab a tutto
/// corpo) con l'account nascosto in un drawer aperto da un hamburger sul
/// lato opposto. Ora: la loyalty e' una schermata propria ([LoyaltyScreen],
/// promossa come prima voce), l'account e' una lista senza livelli nascosti.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  String _customerName = '';
  String _customerSurname = '';
  String _customerEmail = '';
  String _customerPhone = '';
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final fullName =
          prefs.getString(AppConstants.keyUserFullname) ?? 'Utente';
      final nameParts = fullName.split(' ');
      _customerName = nameParts.isNotEmpty ? nameParts[0] : '';
      _customerSurname = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      _customerEmail = prefs.getString(AppConstants.keyUserEmail) ?? '';
      _customerPhone = prefs.getString(AppConstants.keyUserPhone) ?? '';
    });
  }

  Future<void> _saveUserData() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.updateProfile(
        firstName: _nameController.text.trim(),
        lastName: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _customerName = _nameController.text.trim();
          _customerSurname = _surnameController.text.trim();
          _customerPhone = _phoneController.text.trim();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Dati salvati con successo'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Errore durante il salvataggio',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileDialog() {
    _nameController.text = _customerName;
    _surnameController.text = _customerSurname;
    _phoneController.text = _customerPhone;

    InputDecoration decorazione(String label, IconData icona) {
      return InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.gray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.gray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        prefixIcon: Icon(icona),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Modifica profilo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: decorazione('Nome', Icons.person),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _surnameController,
                decoration: decorazione('Cognome', Icons.person_outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: decorazione('Telefono', Icons.phone),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annulla',
              style: TextStyle(color: AppColors.gray),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveUserData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
            child: const Text(
              'Salva',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Cancellazione dell'account su richiesta dell'utente.
  ///
  /// Due passaggi voluti: la prima schermata spiega cosa succede, la seconda
  /// chiede di scrivere ELIMINA. E' irreversibile e non deve poter partire per
  /// un tocco distratto.
  Future<void> _handleDeleteAccount() async {
    final primaConferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Verranno eliminati definitivamente il tuo profilo, i tuoi indirizzi, '
          'i metodi di pagamento salvati e i tuoi preferiti.\n\n'
          'Gli ordini gia\' effettuati restano registrati in forma anonima, come '
          'richiesto dalla normativa fiscale.\n\n'
          'L\'operazione non puo\' essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continua',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (primaConferma != true || !mounted) return;

    final controller = TextEditingController();
    final confermaFinale = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confermi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scrivi ELIMINA per confermare.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().toUpperCase() == 'ELIMINA',
            ),
            child: const Text(
              'Elimina definitivamente',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confermaFinale != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await AuthService().deleteAccount();

    if (!mounted) return;
    Navigator.pop(context); // chiude il caricamento

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor:
            response.success ? AppColors.success : AppColors.danger,
      ),
    );

    if (response.success) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/login');
    }
  }

  /// Diagnostica riservata (pressione lunga sul numero di versione).
  ///
  /// Serve a verificare che la catena di segnalazione arrivi davvero a
  /// Crashlytics: invia prima un evento NON fatale e poi, su conferma,
  /// provoca un crash reale. In debug le segnalazioni sono disattivate per
  /// scelta, quindi la prova va fatta su una build di release.
  Future<void> _diagnosticaCrash() async {
    final esiti = <String>[];

    esiti.add('Firebase inizializzato: ${Firebase.apps.length} app'
        '${Firebase.apps.isNotEmpty ? ' (${Firebase.apps.first.name})' : ''}');

    try {
      final attiva =
          FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
      esiti.add('Raccolta attiva: $attiva');
      if (!attiva) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        esiti.add('  -> riattivata ora');
      }
    } catch (e) {
      esiti.add('Raccolta: ERRORE $e');
    }

    try {
      await FirebaseCrashlytics.instance.setCustomKey('diagnostica', true);
      esiti.add('Chiave personalizzata: ok');
    } catch (e) {
      esiti.add('Chiave personalizzata: ERRORE $e');
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        'Test diagnostico dal profilo',
        StackTrace.current,
        reason: 'verifica manuale Crashlytics',
        fatal: false,
      );
      esiti.add('Segnalazione non fatale: inviata');
    } catch (e) {
      esiti.add('Segnalazione non fatale: ERRORE $e');
    }

    try {
      await FirebaseCrashlytics.instance.sendUnsentReports();
      esiti.add('Invio forzato della coda: ok');
    } catch (e) {
      esiti.add('Invio forzato della coda: ERRORE $e');
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnostica Crashlytics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...esiti.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(r, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Se sopra e\' tutto ok, premi "Forza crash": l\'app si '
                'chiudera\'. Riaprila e il crash verra\' spedito.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Crash nativo: lo raccoglie il gestore di Crashlytics
              FirebaseCrashlytics.instance.crash();
            },
            child: const Text(
              'Forza crash',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _authService.logout();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il logout: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text(
          'Profilo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: AppColors.light,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(
'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_customerName $_customerSurname',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (_customerEmail.isNotEmpty)
                              Text(
                                _customerEmail,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: AppIcon(
'assets/icons/icons8-modifica-32.png',
                          width: 20,
                          height: 20,
                          color: Colors.white,
                        ),
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Programma fedelta' in evidenza: e' il motivo per cui
                // molti aprono il profilo
                _buildTile(
                  icon: 'assets/icons/icons8-stella-32.png',
                  title: 'Programma fedeltà',
                  subtitle: 'Punti, livelli e premi',
                  highlighted: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoyaltyScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildTile(
                  icon: 'assets/icons/icons8-indirizzo-32.png',
                  title: 'I miei indirizzi',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressesScreen(),
                    ),
                  ),
                ),
                _buildTile(
                  icon: 'assets/icons/icons8-ordine-di-acquisto-32.png',
                  title: 'I miei ordini',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  ),
                ),
                _buildTile(
                  icon: 'assets/icons/icons8-portafoglio-32.png',
                  title: 'Wallet',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalletScreen(),
                    ),
                  ),
                ),
                _buildTile(
                  icon: 'assets/icons/icons8-allarme-32.png',
                  title: 'Notifiche',
                  onTap: () => context.push('/notifications'),
                ),
                _buildTile(
                  icon: 'assets/icons/icons8-supporto-32.png',
                  title: 'Supporto',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SupportScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildTile(
                  icon: 'assets/icons/icons8-uscita-32.png',
                  title: 'Logout',
                  onTap: _handleLogout,
                ),

                // Cancellazione account: obbligatoria per Google Play e
                // diritto dell'interessato (GDPR). In fondo e in rosso.
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.danger,
                      size: 22,
                    ),
                    title: const Text(
                      'Elimina account',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    onTap: _handleDeleteAccount,
                  ),
                ),

                // Versione. Pressione LUNGA = diagnostica Crashlytics
                // riservata (invisibile a chi non la conosce).
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: _diagnosticaCrash,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Lenny v${AppConstants.appVersion}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gray,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTile({
    required String icon,
    required String title,
    String? subtitle,
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: highlighted
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
            : null,
      ),
      child: ListTile(
        leading: Image.asset(
          icon,
          width: 24,
          height: 24,
          color: AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grayDark,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.gray,
          size: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        onTap: onTap,
      ),
    );
  }
}
