import 'package:flutter_webrtc/flutter_webrtc.dart';

enum P2PCallStatus { idle, incoming, active }

class P2PCallState {
  final P2PCallStatus status;
  final String? chatId;
  final String? callerName;
  final bool isVideo;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final RTCPeerConnection? peerConnection;
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
