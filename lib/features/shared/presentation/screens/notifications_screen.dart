import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/screen_titles.dart';

/// Notification model
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'prescription', 'emergency', 'system', 'reminder'
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
}

/// Provider for notifications (placeholder - can be connected to Supabase later)
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
      return NotificationsNotifier();
    });

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super(_getSampleNotifications());

  static List<AppNotification> _getSampleNotifications() {
    return [
      AppNotification(
        id: '1',
        title: 'Welcome to CareSync',
        message:
            'Your account has been set up successfully. Complete your profile to get started.',
        type: 'system',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: '2',
        title: 'Complete Your Profile',
        message:
            'Add your emergency contact and medical conditions for better emergency response.',
        type: 'reminder',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: true,
      ),
    ];
  }

  void markAsRead(String id) {
    state =
        state.map((n) {
          if (n.id == id) {
            return AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              createdAt: n.createdAt,
              isRead: true,
            );
          }
          return n;
        }).toList();
  }

  void markAllAsRead() {
    state =
        state.map((n) {
          return AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            createdAt: n.createdAt,
            isRead: true,
          );
        }).toList();
  }

  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }

  void addNotification({
    required String title,
    required String message,
    required String type,
  }) {
    final newNotif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );
    state = [newNotif, ...state];
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

/// Provider for unread count
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Returns the icon + accent/error color for a notification type.
({IconData icon, bool isError}) _notificationStyle(String type) {
  switch (type) {
    case 'prescription':
      return (icon: Iconsax.document_text, isError: false);
    case 'emergency':
      return (icon: Iconsax.danger, isError: true);
    case 'reminder':
      return (icon: Iconsax.clock, isError: false);
    case 'system':
    default:
      return (icon: Iconsax.info_circle, isError: false);
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return CSScaffold(
      title: ScreenTitles.notifications,
      actions: [
        if (notifications.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(Iconsax.more, color: t.textPrimary),
            color: t.card,
            onSelected: (value) {
              switch (value) {
                case 'read_all':
                  notifier.markAllAsRead();
                  break;
                case 'clear_all':
                  notifier.clearAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications cleared')),
                  );
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'read_all',
                    child: Row(
                      children: [
                        Icon(Iconsax.tick_circle),
                        SizedBox(width: 12),
                        Text('Mark all as read'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Iconsax.trash),
                        SizedBox(width: 12),
                        Text('Clear all'),
                      ],
                    ),
                  ),
                ],
          ),
      ],
      body:
          notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.notification,
                      size: 80,
                      color: t.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(color: t.textSecondary),
                    ),
                  ],
                ),
              )
              : ListView.separated(
                padding: AppSpacing.screenPadding,
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationCard(
                    notification: notification,
                    onTap: () {
                      notifier.markAsRead(notification.id);
                      _handleNotificationTap(context, notification);
                    },
                    onDismiss: () {
                      notifier.deleteNotification(notification.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Notification removed'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
  ) {
    final style = _notificationStyle(notification.type);
    showAppSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        final color = style.isError ? t.error : t.accent;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(style.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(notification.title, style: t.sheetTitle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatDate(notification.createdAt),
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: t.error,
          borderRadius: BorderRadius.circular(AppSpacing.squircleGrouped),
        ),
        child: Icon(Iconsax.trash, color: t.accentOn),
      ),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        color: notification.isRead ? t.card : t.tint,
        borderSide: BorderSide(
          color:
              notification.isRead ? t.divider : t.accent.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight:
                                notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                            fontSize: 15,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimeAgo(notification.createdAt),
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final t = context.tokens;
    final style = _notificationStyle(notification.type);
    final color = style.isError ? t.error : t.accent;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(style.icon, color: color, size: 22),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
