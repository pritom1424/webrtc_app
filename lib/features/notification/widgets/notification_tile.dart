import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';
import 'package:webrtc_app/core/services/notification_service.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/notification/model/app_notification.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final type = notification.data['type'] as String? ?? 'message';
    String _formatTime(DateTime? dt) {
      if (dt == null) return '';
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    }

    Color _iconColor(String type) {
      switch (type) {
        case 'call':
        case 'video_call':
          return Colors.green;
        case 'conference':
          return Colors.orange;
        default:
          return AppColors.primaryBlue;
      }
    }

    IconData _iconData(String type) {
      switch (type) {
        case 'call':
          return Icons.call_rounded;
        case 'video_call':
          return Icons.videocam_rounded;
        case 'conference':
          return Icons.group_rounded;
        default:
          return Icons.message_rounded;
      }
    }

    return Container(
      color: isUnread
          ? AppColors.primaryBlue.withValues(alpha: 0.05)
          : Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _iconColor(type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconData(type), color: _iconColor(type), size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        onTap: () {
          NotificationService.instance.markAsRead(notification.id);
        },
      ),
    );
  }
}
