import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/core/widgets/message_bubble.dart';
import 'package:webrtc_app/features/call/model/conference_state.dart';
import 'package:webrtc_app/features/call/provider/conference_notifier.dart';
import 'package:webrtc_app/features/chat/provider/room_chat_provider.dart';
import 'package:webrtc_app/features/chat/screen/widgets/room_members_tab.dart';

class RChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  const RChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  ConsumerState<RChatScreen> createState() => _RChatScreenState();
}

class _RChatScreenState extends ConsumerState<RChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  RTCVideoRenderer? local;
  RTCVideoRenderer? remote;
  late TabController _tabController;
  //for conference call
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  RTCVideoRenderer? _localRenderer;
  //for conference call
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    //for conference call
    // Start watching room for activeConference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conferenceProvider.notifier).watchRoom(widget.roomId);
    });
    //for conference call
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();

    //for conference call
    _disposeRenderers();
    if (ref.read(conferenceProvider).isActive) {
      ref.read(conferenceProvider.notifier).leaveConference();
    }
    //for conference call
    super.dispose();
  }

  //for conference call
  // Existing — called when screen closes, disposes everything
  void _disposeRenderers() {
    _localRenderer?.dispose();
    _localRenderer = null;
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _remoteRenderers.clear();
  }

  // New — called when a single peer leaves mid-call
  void _removePeerRenderer(String peerId) {
    final renderer = _remoteRenderers[peerId];
    if (renderer != null) {
      renderer.dispose();
      setState(() => _remoteRenderers.remove(peerId));
    }
  }

  //for conference call
  //for conference call
  Future<void> _initRenderers(ConferenceState confState) async {
    if (confState.localStream != null) {
      if (_localRenderer == null) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = confState.localStream;
        if (mounted) setState(() => _localRenderer = renderer);
      } else if (_localRenderer!.srcObject != confState.localStream) {
        // Stream changed on rejoin — update instead of skip
        _localRenderer!.srcObject = confState.localStream;
        if (mounted) setState(() {});
      }
    }
    // Remote renderers — one per peer
    for (final entry in confState.remoteStreams.entries) {
      if (!_remoteRenderers.containsKey(entry.key)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        // Small delay for emulator camera to be ready
        await Future.delayed(const Duration(milliseconds: 300));
        renderer.srcObject = entry.value;
        setState(() {
          _remoteRenderers[entry.key] = renderer;
        });
      }
    }
  }

  //for conference call

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    // Call sendMessage on the notifier
    ref.read(chatProvider(widget.roomId).notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    //for conference call
    // Listen to conference state changes
    ref.listen<ConferenceState>(conferenceProvider, (previous, next) {
      if (previous?.status != ConferenceStatus.active &&
          next.status == ConferenceStatus.active) {
        _initRenderers(next);
      }

      if (next.remoteStreams.length != (previous?.remoteStreams.length ?? 0)) {
        _initRenderers(next);

        // Remove renderers for peers who left
        final removedPeers = _remoteRenderers.keys
            .where((id) => !next.remoteStreams.containsKey(id))
            .toList();

        for (final peerId in removedPeers) {
          _removePeerRenderer(peerId);
        }
      }

      // Conference fully ended — dispose all renderers
      // Dispose as soon as conference stops (not just when idle)
      if (previous?.isActive == true && !next.isActive) {
        _disposeRenderers();
      }
    });
    final confState = ref.watch(conferenceProvider);
    print(confState.isActive);
    //for conference call
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(confState),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildChatTab(), RoomMembersTab(widget.roomId)],
                  ),
                ),
              ],
            ),
          ),
          //for conference call
          // Conference overlay — shown on top of chat
          if (confState.isActive)
            Positioned.fill(child: _buildConferenceOverlay(confState)),
          // Incoming call dialog
          // Mirrors: _buildIncomingCallUI(...)
          if (confState.isIncoming)
            Positioned.fill(child: _buildIncomingConferenceDialog(confState)),

          //for conference call
        ],
      ),
    );
  }

  Widget _buildAppBar(ConferenceState confState) {
    // Watch active conference from Firestore directly
    final activeConferenceAsync = ref.watch(
      activeConferenceProvider(widget.roomId),
    );

    // Is there an active conference right now?
    final activeConference = activeConferenceAsync.asData?.value;
    final conferenceIsLive =
        activeConference != null && activeConference['status'] == 'active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.roomName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Show "Conference active" indicator
                if (conferenceIsLive && !confState.isActive)
                  const Text(
                    '🔴 Conference in progress',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  )
                else
                  Text(
                    'ID: ${widget.roomId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),

          // ── Appbar action button logic ──
          if (confState.isActive)
            // We are IN the conference — show end call
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: () =>
                  ref.read(conferenceProvider.notifier).leaveConference(),
            )
          else if (conferenceIsLive)
            // Conference live — join button
            TextButton.icon(
              icon: const Icon(Icons.call, color: Colors.white),
              label: const Text(
                'Join Conference',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () {
                final isVideo = activeConference['isVideo'] as bool? ?? true;
                ref
                    .read(conferenceProvider.notifier)
                    .joinConference(roomId: widget.roomId, isVideo: isVideo);
              },
            )
          else
          // No conference active — show Start
          ...[
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              tooltip: 'Start Audio Conference',
              onPressed: () => ref
                  .read(conferenceProvider.notifier)
                  .startConference(roomId: widget.roomId, isVideo: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              tooltip: 'Start Video Conference',
              onPressed: () => ref
                  .read(conferenceProvider.notifier)
                  .startConference(roomId: widget.roomId, isVideo: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,

        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.primaryBlue,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Chat'),
          Tab(text: 'Members'),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final chatAsync = ref.watch(chatProvider(widget.roomId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return chatAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No messages yet.\nSay hello!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (ctx, ind) {
            final msg = messages[ind];
            final isMe = msg.senderId == currentUid;
            return MessageBubble(message: msg, isMe: isMe);
          },
        );
      },
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.buttonBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
  //for conference call
  // ── Conference Overlay ────────────────────────────────────
  // Shown on top of chat when conference is active
  // Mirrors: _buildOngoingCallUI() from original Bloc code

  Widget _buildConferenceOverlay(ConferenceState confState) {
    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          confState.isVideo
              ? _buildVideoGrid(confState)
              : _buildAudioGrid(confState),

          // Local video — small in corner
          if (_localRenderer != null)
            Positioned(
              right: 12,
              bottom: 90, // above the end call button
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer!,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          // Member names bar
          Positioned(
            top: 12,
            left: 12,
            right: 120,
            child: Wrap(
              spacing: 8,
              children: confState.memberNames.values
                  .map(
                    (name) => Chip(
                      label: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ),

          // End call button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () =>
                      ref.read(conferenceProvider.notifier).leaveConference(),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(ConferenceState confState) {
    if (_remoteRenderers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Waiting for others to join...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () =>
                  ref.read(conferenceProvider.notifier).leaveConference(),
              icon: const Icon(Icons.exit_to_app, color: Colors.white54),
              label: const Text(
                'Leave conference',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }
    final renderers = _remoteRenderers.values.toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 250),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: renderers.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: renderers.length,
      itemBuilder: (context, index) {
        final peerId = _remoteRenderers.keys.elementAt(index);
        final peerName = confState.memberNames[peerId] ?? "Unknown";
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              RTCVideoView(
                renderers[index],
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              // Name label on each video
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    peerName,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Incoming Conference Dialog ────────────────────────────
  // Shown when another user starts a conference
  Widget _buildIncomingConferenceDialog(ConferenceState confState) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_call_rounded,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),
            Text(
              '${confState.startedByName} started a conference call',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              widget.roomName, // widget.roomName
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                // Dismiss
                // Mirrors: Reject button in original
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(conferenceProvider.notifier).dismissIncoming(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),

                const SizedBox(width: 12),
                // Join
                // Mirrors: Accept button in original
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final activeConference = ref
                          .read(activeConferenceProvider(widget.roomId))
                          .asData
                          ?.value;
                      final isVideo =
                          activeConference?['isVideo'] as bool? ?? true;
                      ref
                          .read(conferenceProvider.notifier)
                          .joinConference(
                            roomId: widget.roomId,
                            isVideo: isVideo,
                          );
                    }, //widget.roomId
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioGrid(ConferenceState confState) {
    final members = confState.memberNames;

    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Waiting for others to join...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () =>
                  ref.read(conferenceProvider.notifier).leaveConference(),
              icon: const Icon(Icons.exit_to_app, color: Colors.white54),
              label: const Text(
                'Leave conference',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 60),

        // Avatar grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: members.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final name = members.values.elementAt(index);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated ring — shows speaking indicator
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.6),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Connected indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Connected',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // Also show yourself
        Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              const Text(
                'You',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.buttonBlue,
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //for conference call
}
