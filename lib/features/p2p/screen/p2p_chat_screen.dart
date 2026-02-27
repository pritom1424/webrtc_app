import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/p2p/model/p2p_call_state.dart';
import 'package:webrtc_app/features/p2p/provider/p2p_call_notifier.dart';
import 'package:webrtc_app/features/p2p/provider/p2p_chat_provider.dart';
import 'package:webrtc_app/features/p2p/provider/p2p_provider.dart';
import 'package:webrtc_app/features/p2p/screen/widgets/p2p_message_bubble.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';

class P2PChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String peerName;

  const P2PChatScreen({
    super.key,
    required this.chatId,
    required this.peerName,
  });

  @override
  ConsumerState<P2PChatScreen> createState() => _P2PChatScreenState();
}

class _P2PChatScreenState extends ConsumerState<P2PChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  // IDENTICAL renderer pattern to RChatScreen — just single instead of Map
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer?
  _remoteRenderer; // ← Map<String,RTCVideoRenderer> in conference

  @override
  void initState() {
    super.initState();
    // IDENTICAL to RChatScreen watchRoom call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(p2pCallProvider.notifier).watchChat(widget.chatId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _disposeRenderers();
    if (ref.read(p2pCallProvider).isActive) {
      ref.read(p2pCallProvider.notifier).endCall();
    }
    super.dispose();
  }

  // IDENTICAL to RChatScreen _disposeRenderers
  void _disposeRenderers() {
    _localRenderer?.dispose();
    _localRenderer = null;
    _remoteRenderer?.dispose();
    _remoteRenderer = null;
  }

  Future<void> _initRenderers(P2PCallState callState) async {
    if (callState.localStream != null) {
      if (_localRenderer == null) {
        final r = RTCVideoRenderer();
        await r.initialize();
        r.srcObject = callState.localStream;
        if (mounted) setState(() => _localRenderer = r);
      } else if (_localRenderer!.srcObject != callState.localStream) {
        _localRenderer!.srcObject = callState.localStream;
        if (mounted) setState(() {});
      }
    }

    if (callState.remoteStream != null) {
      if (_remoteRenderer == null) {
        final r = RTCVideoRenderer();
        await r.initialize();
        r.srcObject = callState.remoteStream;
        if (mounted) {
          setState(() {
            _remoteRenderer = r;
          });
        }
      } else if (_remoteRenderer!.srcObject != callState.remoteStream) {
        await _remoteRenderer!.dispose();
        _remoteRenderer = null;
        final r = RTCVideoRenderer();
        await r.initialize();
        r.srcObject = callState.remoteStream;
        if (mounted) setState(() => _remoteRenderer = r);
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    ref.read(p2pChatProvider(widget.chatId).notifier).sendMessage(text);
  }

  String _getPeerId() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chats = ref.read(myP2PChatsProvider).asData?.value ?? [];
    final chat = chats.firstWhere(
      (c) => c.chatId == widget.chatId,
      orElse: () => throw Exception('Chat not found'),
    );
    return chat.partnerId(myUid);
  }

  @override
  Widget build(BuildContext context) {
    // IDENTICAL ref.listen pattern to RChatScreen
    ref.listen<P2PCallState>(p2pCallProvider, (previous, next) {
      if (previous?.status != P2PCallStatus.active &&
          next.status == P2PCallStatus.active) {
        _initRenderers(next);
      }
      if (next.remoteStream != null &&
          next.remoteStream != previous?.remoteStream) {
        _initRenderers(next);
      }
      if (previous?.isActive == true && !next.isActive) {
        _disposeRenderers();
      }
    });

    final callState = ref.watch(p2pCallProvider);
    final activeCallAsync = ref.watch(p2pActiveCallProvider(widget.chatId));
    final activeCall = activeCallAsync.asData?.value;
    final callIsLive = activeCall != null && activeCall['status'] == 'calling';

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(callState, activeCall, callIsLive),
                Expanded(child: _buildChatArea()),
              ],
            ),
          ),

          // IDENTICAL overlay pattern to RChatScreen conference overlay
          if (callState.isActive)
            Positioned.fill(child: _buildCallOverlay(callState)),

          // IDENTICAL incoming dialog pattern to RChatScreen
          // Difference: Accept/Reject instead of Join/Dismiss
          if (callState.isIncoming)
            Positioned.fill(child: _buildIncomingCallDialog(callState)),
        ],
      ),
    );
  }

  // IDENTICAL to RChatScreen _buildAppBar — tweaked for P2P buttons
  Widget _buildAppBar(
    P2PCallState callState,
    Map<String, dynamic>? activeCall,
    bool callIsLive,
  ) {
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
                  widget.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (callIsLive && !callState.isActive)
                  const Text(
                    '🔴 Call in progress',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  )
                else
                  const Text(
                    'Direct Message',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),

          // IDENTICAL button logic to RChatScreen — P2P differences noted
          if (callState.isActive)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: () => ref.read(p2pCallProvider.notifier).endCall(),
            )
          else if (callState.isIncoming) ...[
            // P2P ONLY: accept + reject (conference shows Join button)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.greenAccent),
              tooltip: 'Accept',
              onPressed: () => ref
                  .read(p2pCallProvider.notifier)
                  .acceptCall(
                    chatId: widget.chatId,
                    isVideo: callState.isVideo,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              tooltip: 'Reject',
              onPressed: () => ref.read(p2pCallProvider.notifier).rejectCall(),
            ),
          ] else if (callIsLive)
            // P2P ONLY: cancel while ringing (conference shows Join button)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              tooltip: 'Cancel Call',
              onPressed: () => ref.read(p2pCallProvider.notifier).cancelCall(),
            )
          else ...[
            // IDENTICAL start call buttons to conference start buttons
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              tooltip: 'Audio Call',
              onPressed: () {
                final peerId = _getPeerId();
                ref
                    .read(p2pCallProvider.notifier)
                    .startCall(
                      chatId: widget.chatId,
                      peerId: peerId,
                      peerName: widget.peerName,
                      isVideo: false,
                    );
              },
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              tooltip: 'Video Call',
              onPressed: () {
                final peerId = _getPeerId();
                ref
                    .read(p2pCallProvider.notifier)
                    .startCall(
                      chatId: widget.chatId,
                      peerId: peerId,
                      peerName: widget.peerName,
                      isVideo: true,
                    );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatArea() {
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
    final chatAsync = ref.watch(p2pChatProvider(widget.chatId));
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
          itemBuilder: (ctx, i) {
            final msg = messages[i];
            final isMe = msg.senderId == currentUid;
            return P2PMessageBubble(message: msg, isMe: isMe);
          },
        );
      },
      error: (e, _) => Center(
        child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
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
                  borderSide: const BorderSide(color: AppColors.lightBlue),
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
                color: AppColors.buttonBlue,
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

  // ── Call Overlay — IDENTICAL to RChatScreen _buildConferenceOverlay ───────

  Widget _buildCallOverlay(P2PCallState callState) {
    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          // IDENTICAL video/audio switch to conference
          callState.isVideo
              ? _buildVideoView(callState)
              : _buildAudioView(callState),

          // IDENTICAL local video corner to conference
          if (_localRenderer != null && callState.isVideo)
            Positioned(
              right: 12,
              bottom: 90,
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

          // Peer name — IDENTICAL to conference member names bar
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  callState.peerName ?? widget.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Connected',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                ),
              ],
            ),
          ),

          // IDENTICAL end call button to conference
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () => ref.read(p2pCallProvider.notifier).endCall(),
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

  // IDENTICAL to conference _buildVideoGrid — just single renderer instead of GridView
  Widget _buildVideoView(P2PCallState callState) {
    if (_remoteRenderer == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Waiting for peer to connect...',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => ref.read(p2pCallProvider.notifier).endCall(),
              icon: const Icon(Icons.exit_to_app, color: Colors.white54),
              label: const Text(
                'Leave call',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }
    return RTCVideoView(
      _remoteRenderer!,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  // IDENTICAL to conference _buildAudioGrid — just single peer avatar
  Widget _buildAudioView(P2PCallState callState) {
    final name = callState.peerName ?? widget.peerName;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.6),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              if (_remoteRenderer == null)
                const Text(
                  'Connecting...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              if (_remoteRenderer != null)
                const Text(
                  'Connected',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // IDENTICAL to RChatScreen _buildIncomingConferenceDialog
  // Difference: Accept/Decline buttons instead of Join/Dismiss
  Widget _buildIncomingCallDialog(P2PCallState callState) {
    final isVideo = callState.isVideo;
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.video_call_rounded : Icons.call_rounded,
                color: AppColors.primaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${callState.callerName} is calling...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isVideo ? 'Video Call' : 'Audio Call',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(p2pCallProvider.notifier).rejectCall(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(p2pCallProvider.notifier)
                        .acceptCall(
                          chatId: widget.chatId,
                          isVideo: callState.isVideo,
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
