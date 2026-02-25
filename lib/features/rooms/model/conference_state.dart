import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ConferenceStatus { idle, incoming, active, ended }

class ConferenceState {
  final ConferenceStatus status;
  final String? roomId;
  final String? startedByName; // who started the call — shown in dialog
  final bool isVideo;
  final MediaStream? localStream;
  final Map<String, RTCPeerConnection> peerConnections;
  final Map<String, MediaStream> remoteStreams;
  final Map<String, String> memberNames;
  final String? errorMessage;

  const ConferenceState({
    this.status = ConferenceStatus.idle,
    this.roomId,
    this.startedByName,
    this.isVideo = true,
    this.localStream,
    this.peerConnections = const {},
    this.remoteStreams = const {},
    this.memberNames = const {},
    this.errorMessage,
  });

  factory ConferenceState.initial() => const ConferenceState();

  bool get isIdle => status == ConferenceStatus.idle;
  bool get isIncoming => status == ConferenceStatus.incoming;
  bool get isActive => status == ConferenceStatus.active;

  ConferenceState copyWith({
    ConferenceStatus? status,
    String? roomId,
    String? startedByName,
    bool? isVideo,
    MediaStream? localStream,
    Map<String, RTCPeerConnection>? peerConnections,
    Map<String, MediaStream>? remoteStreams,
    Map<String, String>? memberNames,
    String? errorMessage,
  }) {
    return ConferenceState(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      startedByName: startedByName ?? this.startedByName,
      isVideo: isVideo ?? this.isVideo, // ← add this
      localStream: localStream ?? this.localStream,
      peerConnections: peerConnections ?? this.peerConnections,
      remoteStreams: remoteStreams ?? this.remoteStreams,
      memberNames: memberNames ?? this.memberNames,
      errorMessage: errorMessage,
    );
  }
}
