import 'package:flutter/material.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/p2p/provider/p2p_provider.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback? onTap;

  const UserTile({
    super.key,
    required this.user,
    required this.isAdded,
    required this.onAdd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
        child: Text(
          user.name[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isAdded ? AppColors.textDark : Colors.black87,
        ),
      ),
      subtitle: Text(
        isAdded ? 'Tap to open chat' : 'Tap + to start chatting',
        style: TextStyle(
          fontSize: 12,
          color: isAdded ? AppColors.primaryBlue : Colors.grey,
        ),
      ),
      trailing: isAdded
          ? Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryBlue,
              size: 20,
            )
          : IconButton(
              icon: const Icon(
                Icons.person_add_alt_1,
                color: AppColors.primaryBlue,
              ),
              tooltip: 'Add to chats',
              onPressed: onAdd,
            ),
    );
  }
}
