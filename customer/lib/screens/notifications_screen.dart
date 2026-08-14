import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../widgets/app_icon.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color primaryBlue = AppColors.primary;
  static const Color dangerRed = AppColors.danger;
  static const Color darkColor = AppColors.dark;
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  @override
  void initState() {
    super.initState();
    // Carica le notifiche e poi segna tutte come lette
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      provider.loadNotifications().then((_) => provider.markAllRead());
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    if (diff.inDays == 1) return 'Ieri';
    return DateFormat('d MMM', 'it_IT').format(dt);
  }

  /// L'icona dell'evento, dal set dell'app dove un simbolo esiste.
  ///
  /// Spunte e annullamenti restano glifi Material di proposito: sono
  /// segnaletica di stato, non contenuto, e il set di Lenny non ha (ne' deve
  /// avere) una spunta doppia. Il ristorante, la consegna e la spesa invece
  /// sono contenuto, e usano le icone di casa.
  Widget _iconForEvent(String? event, Color color) {
    switch (event) {
      case 'order_confirmed':
        return Icon(Icons.check_circle_outline, color: color, size: 22);
      case 'order_ready':
        return AppIcon(
          'assets/icons_svg/icons8-ristorante-32.svg',
          color: color,
          size: 22,
        );
      case 'order_out_for_delivery':
        return AppIcon(
          'assets/icons_svg/lenny-consegna.svg',
          color: color,
          size: 22,
        );
      case 'order_delivered':
        return Icon(Icons.done_all, color: color, size: 22);
      case 'order_cancelled':
        return Icon(Icons.cancel_outlined, color: color, size: 22);
      case 'new_order':
        return AppIcon(
          'assets/icons_svg/icons8-borsa-della-spesa-32.svg',
          color: color,
          size: 22,
        );
      default:
        return AppIcon(
          'assets/icons_svg/icons8-allarme-32.svg',
          color: color,
          size: 22,
        );
    }
  }

  Color _colorForEvent(String? event) {
    switch (event) {
      case 'order_confirmed':
        return AppColors.success;
      case 'order_ready':
        return AppColors.warning;
      case 'order_out_for_delivery':
        return primaryBlue;
      case 'order_delivered':
        return AppColors.success;
      case 'order_cancelled':
        return dangerRed;
      default:
        return primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: darkColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifiche',
          style: TextStyle(
            color: darkColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        // Niente "Segna tutte": all'apertura le notifiche vengono gia'
        // marcate lette in automatico (initState), il bottone era ridondante.
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            );
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: lightGrayColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessuna notifica',
                    style: TextStyle(
                      fontSize: 16,
                      color: grayColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Le notifiche sui tuoi ordini appariranno qui',
                    style: TextStyle(fontSize: 13, color: AppColors.gray),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: primaryBlue,
            onRefresh: provider.loadNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) =>
                  _buildItem(provider.notifications[index], provider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(CustomerNotification notif, NotificationProvider provider) {
    final color = _colorForEvent(notif.triggerEvent);
    final icon = _iconForEvent(notif.triggerEvent, color);

    return GestureDetector(
      onTap: () {
        if (!notif.isRead) provider.markRead(notif.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFEEF3FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? Colors.transparent
                : primaryBlue.withAlpha(60),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icona
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 12),
              // Testo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                              color: darkColor,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(notif.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: grayColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: grayColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Punto non letto
              if (!notif.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
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
