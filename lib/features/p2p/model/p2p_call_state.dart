// ── P2P Call State ─────────────────────────────────────────────────────────
// IDENTICAL to ConferenceState except:
//   • status enum is P2PCallStatus (idle/incoming/active) not ConferenceStatus
//   • remoteStreams is a single MediaStream? not Map<String,MediaStream>
//   • peerConnections is a single RTCPeerConnection? not Map<String,RTCPeerConnection>
//   • peerId/peerName instead of memberNames map
//   • callerName for incoming display
//   • chatId instead of roomId

import 'package:flutter_webrtc/flutter_webrtc.dart';

enum P2PCallStatus { idle, incoming, active }

class P2PCallState {
  final P2PCallStatus status;
  final String? chatId; // ← roomId equivalent
  final String? callerName; // ← startedByName equivalent
  final bool isVideo;
  final MediaStream? localStream;
  final MediaStream? remoteStream; // ← single stream (conference has Map)
  final RTCPeerConnection? peerConnection; // ← single pc (conference has Map)
  final String? peerId;
  final String? peerName;

  const P2PCallState({
    this.status = P2PCallStatus.idle,
    this.chatId,
    this.callerName,
    this.isVideo = true,
    this.localStream,
    this.remoteStream,
    this.peerConnection,
    this.peerId,
    this.peerName,
  });

  factory P2PCallState.initial() => const P2PCallState();

  bool get isIdle => status == P2PCallStatus.idle;
  bool get isIncoming => status == P2PCallStatus.incoming;
  bool get isActive => status == P2PCallStatus.active;

  P2PCallState copyWith({
    P2PCallStatus? status,
    String? chatId,
    String? callerName,
    bool? isVideo,
    MediaStream? localStream,
    MediaStream? remoteStream,
    RTCPeerConnection? peerConnection,
    String? peerId,
    String? peerName,
    bool clearRemoteStream = false,
  }) {
    return P2PCallState(
      status: status ?? this.status,
      chatId: chatId ?? this.chatId,
      callerName: callerName ?? this.callerName,
      isVideo: isVideo ?? this.isVideo,
      localStream: localStream ?? this.localStream,
      remoteStream: clearRemoteStream
          ? null
          : (remoteStream ?? this.remoteStream),
      peerConnection: peerConnection ?? this.peerConnection,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
    );
  }
}
