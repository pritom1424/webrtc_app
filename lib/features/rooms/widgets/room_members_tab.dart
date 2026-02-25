import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/rooms/provider/room_chat_provider.dart';
import 'package:webrtc_app/features/profile/provider/profile_notifier.dart';

class RoomMembersTab extends ConsumerWidget {
  final String roomId;
  const RoomMembersTab(this.roomId, {super.key});

  Future<void> _leaveRoom(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Room'),
        content: const Text(
          'Are you sure you want to leave this room? You will need to be invited back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'members': FieldValue.arrayRemove([uid]),
      });

      if (context.mounted) {
        Navigator.pop(context); // pop RChatScreen
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(roomMembersProvider(roomId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: membersAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members found'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: members.length,
                  separatorBuilder: (_, __) =>
                      const Divider(indent: 72, endIndent: 20),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isMe = member['uid'] == currentUid;
                    final name = member['name'] ?? 'Unknown';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        isMe ? '$name (You)' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: Text(
                        member['loginId'] ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isMe
                          ? const Chip(
                              label: Text(
                                'You',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: Color(0xFFE3F2FD),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                            )
                          : null, // no buttons for other members
                    );
                  },
                ),
              ),

              // ── Leave Room Button ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _leaveRoom(context),
                    icon: const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Leave Room',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
