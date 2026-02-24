import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/p2p/model/p2p_chat_model.dart';
import 'package:webrtc_app/features/p2p/provider/p2p_provider.dart';
import 'package:webrtc_app/features/p2p/screen/p2p_chat_screen.dart';
import 'package:webrtc_app/features/p2p/screen/widgets/user_tile.dart';

class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  void _navigateToChat(BuildContext context, P2PChatModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PChatScreen(
          chatId: chat.chatId,
          peerName: chat.partnerName(
            FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final usersAsync = ref.watch(p2pProvider);
    final myChatsAsync = ref.watch(myP2PChatsProvider);

    // Build a set of uids we already have chats with — O(1) lookup
    final chattedUids =
        myChatsAsync.asData?.value
            .expand((chat) => chat.participants)
            .where((uid) => uid != currentUid)
            .toSet() ??
        {};

    // Map peerId → chatId for navigation
    final peerChatMap = {
      for (final chat in myChatsAsync.asData?.value ?? [])
        chat.partnerId(currentUid): chat,
    };

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /* const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BDCOM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Direct Messages',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ), */
                      const Padding(
                        padding: EdgeInsets
                            .zero, //EdgeInsets.fromLTRB(20, 0, 20, 12)
                        child: Text(
                          'All Users',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),

                // ── User List Card ──
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: usersAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Error: $e',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        data: (users) {
                          if (users.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 52,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No other users yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: users.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 20,
                              endIndent: 20,
                            ),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isAdded = chattedUids.contains(user.uid);
                              final chat = peerChatMap[user.uid];

                              return UserTile(
                                user: user,
                                isAdded: isAdded,
                                onAdd: () async {
                                  final newChat = await ref
                                      .read(p2pProvider.notifier)
                                      .addChat(user);
                                  if (newChat != null && context.mounted) {
                                    _navigateToChat(context, newChat);
                                  }
                                },
                                onTap: isAdded && chat != null
                                    ? () => _navigateToChat(context, chat)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
