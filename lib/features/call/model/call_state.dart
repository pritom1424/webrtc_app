import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/features/call/model/call_model.dart';

class CallState {
  final CallModel? currentCall;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final RTCPeerConnection? peerConnection;
  final String? errorMessage;

  CallState({
    this.currentCall,
    this.localStream,
    this.remoteStream,
    this.peerConnection,
    this.errorMessage,
  });

  factory CallState.initial() => CallState();

  CallState copyWith({
    CallModel? currentCall,
    MediaStream? localStream,
    MediaStream? remoteStream,
    RTCPeerConnection? peerConnection,
    String? errorMessage,
  }) {
    return CallState(
      currentCall: currentCall ?? this.currentCall,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      peerConnection: peerConnection ?? this.peerConnection,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
