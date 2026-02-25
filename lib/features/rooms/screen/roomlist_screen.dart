import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/constants/app_nav_paths.dart';
import 'package:webrtc_app/core/services/notification_service.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/rooms/screen/roomchat_screen.dart';
import 'package:webrtc_app/features/rooms/model/room_model.dart';
import 'package:webrtc_app/features/rooms/provider/room_notifier.dart';
import 'package:webrtc_app/features/rooms/widgets/room_tiled.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  final _roomNameController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  void _showCreateRoomDialog() {
    _roomNameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Create Room',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _roomNameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Room name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _roomNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await ref.read(roomProvider.notifier).createRoom(name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _navigateToRoom(RoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => RChatScreen(roomId: room.id, roomName: room.name),
      ),
    );
  }

  Future<void> _joinRoom(String roomId) async {
    await ref.read(roomProvider.notifier).joinRoom(roomId);
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppNavPaths.loginPage);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final roomsAsync = ref.watch(roomProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'Available Rooms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Create room in app bar
                          IconButton(
                            onPressed: _showCreateRoomDialog,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Create Room',
                          ),
                          IconButton(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: Colors.white),
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      child: roomsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Error: $e',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        data: (rooms) {
                          if (rooms.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.meeting_room_outlined,
                                    size: 52,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No rooms yet.\nTap + to create one!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: rooms.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 20,
                              endIndent: 20,
                            ),
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              final isJoined =
                                  currentUid != null &&
                                  room.isMember(currentUid);

                              return RoomTile(
                                room: room,
                                isJoined: isJoined,
                                onJoin: () => _joinRoom(room.id),
                                // Joined - tappable to enter room
                                // Not joined - null = not tappable
                                onTap: isJoined
                                    ? () => _navigateToRoom(room)
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
