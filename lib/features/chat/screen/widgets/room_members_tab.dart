import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/chat/provider/room_chat_provider.dart';

class RoomMembersTab extends ConsumerWidget {
  final String roomId;
  const RoomMembersTab(this.roomId, {super.key});

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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members found'));
          }

          return ListView.separated(
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
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  isMe ? '$name (You)' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                subtitle: Text(
                  member['loginId'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: isMe
                    ? const Chip(
                        label: Text(
                          'You',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: Color(0xFFE3F2FD),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // P2P voice call — calls this specific member
                          IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: AppTheme.primaryBlue,
                            ),
                            tooltip: 'Voice call',
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/call',
                              arguments: {
                                'roomId': roomId,
                                'targetUserId': member['uid'],
                                'targetUserName': name,
                                'isVideo': false,
                              },
                            ),
                          ),
                          // P2P video call — calls this specific member
                          IconButton(
                            icon: const Icon(
                              Icons.video_call,
                              color: AppTheme.primaryBlue,
                            ),
                            tooltip: 'Video call',
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/call',
                              arguments: {
                                'roomId': roomId,
                                'targetUserId': member['uid'],
                                'targetUserName': name,
                                'isVideo': true,
                              },
                            ),
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
