import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:webrtc_app/features/call/model/call_model.dart';
import 'package:webrtc_app/features/call/model/call_state.dart';

class CallNotifier extends StateNotifier<CallState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _callSubscription;
  CallNotifier() : super(CallState.initial()) {
    _setupCallListeners();
  }

  void _setupCallListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    _roomSubscription = _firestore.collection("rooms").snapshots().listen((
      snapshot,
    ) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final roomData = change.doc.data()!;
          if (roomData.containsKey('activeCall')) {
            final call = CallModel.fromJson(
              roomData['activeCall'] as Map<String, dynamic>,
            );
            if (call.receiverId == userId &&
                call.status == CallStatus.calling) {
              _onReceiveCall(call);
            }
          }
        }
      }
    });
  }

  void _onReceiveCall(CallModel incomingCall) {
    state = state.copyWith(currentCall: incomingCall);
  }

  Future<void> startCall({
    required String roomId,
    required String receiverId,
    required String receiverName,
    required CallType type,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      // Fetch name from Firestore — anonymous auth has no displayName
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final callerName = userDoc.data()?['name'] ?? 'Unknown';
      final call = CallModel(
        callId: Uuid().v4(),
        callerId: currentUser.uid,
        callerName: callerName,
        receiverId: receiverId,
        receiverName: receiverName,
        type: type,
        roomId: roomId,
        status: CallStatus.calling,
        startTime: DateTime.now(),
      );
      final localStream = await _createLocalStream(type);
      final peerConnection = await _createPeerConnection();
      localStream.getTracks().forEach((track) {
        peerConnection.addTrack(track);
      });
      final offer = await peerConnection.createOffer();
      peerConnection.setLocalDescription(offer);
      await _firestore.collection('rooms').doc(roomId).update({
        'activeCall': {...call.toJson(), 'offer': offer.sdp},
      });
      state = state.copyWith(
        currentCall: call,
        localStream: localStream,
        peerConnection: peerConnection,
      );
      _setupPeerConnectionListeners(peerConnection);
      _listenForAnswer(roomId, peerConnection);
      _listenForIceCandidates(roomId, peerConnection);
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = state.copyWith(errorMessage: e.toString());
      await endCall(roomId: roomId);
    }
  }

  Future<void> acceptCall({
    required String roomId,
    required CallModel activeCall,
  }) async {
    try {
      final currenUser = _auth.currentUser;
      if (currenUser == null) throw Exception("User not authenticated");
      final roomDoc = await _firestore.collection("rooms").doc(roomId).get();
      final offerSdp = roomDoc.data()?['activeCall']['offer'] as String?;
      if (offerSdp == null) throw Exception('No offer found');
      final localStream = await _createLocalStream(activeCall.type);
      final peerConnection = await _createPeerConnection();
      localStream.getTracks().forEach((track) {
        peerConnection.addTrack(track, localStream);
      });
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(offerSdp, 'offer'),
      );
      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      await _firestore.collection('rooms').doc(roomId).update({
        'activeCall.status': CallStatus.connected.toString(),
        'activeCall.answer': answer.sdp,
      });
      state = state.copyWith(
        currentCall: activeCall.copyWith(status: CallStatus.connected),
        localStream: localStream,
        peerConnection: peerConnection,
      );
      _setupPeerConnectionListeners(peerConnection);
      _listenForIceCandidates(roomId, peerConnection);
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = state.copyWith(errorMessage: e.toString());
      await endCall(roomId: roomId);
    }
  }

  void updateCallStatus(CallStatus status) {
    final call = state.currentCall;
    if (call != null) {
      state = state.copyWith(currentCall: call.copyWith(status: status));
    }
  }

  Future<void> endCall({required String roomId}) async {
    try {
      if (state.currentCall != null) {
        await _firestore.collection('rooms').doc(roomId).update({
          'activeCall.status': CallStatus.ended.toString(),
          'activeCall.ended': DateTime.now().toIso8601String(),
        });
      }
      _cleanupCallResources();
      state = CallState.initial();
    } catch (e) {
      log(e.toString());
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void _cleanupCallResources() {
    state.localStream?.dispose();
    state.peerConnection?.dispose();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    return await createPeerConnection({
      'iceServers': [
        {
          "urls": [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
          ],
        },
      ],
    });
  }

  void _setupPeerConnectionListeners(RTCPeerConnection peerConnection) {
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      final call = state.currentCall;
      if (call != null) {
        _firestore
            .collection('rooms')
            .doc(call.roomId)
            .collection('candidates')
            .add(candidate.toMap());
      }
    };
  }

  void _listenForIceCandidates(
    String roomId,
    RTCPeerConnection peerConnection,
  ) {
    _firestore
        .collection('rooms')
        .doc(roomId)
        .collection("candidates")
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data()!;
              peerConnection.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
          }
        });
  }

  void _listenForAnswer(String roomId, RTCPeerConnection peerConnection) {
    _firestore.collection('rooms').doc(roomId).snapshots().listen((
      snapshot,
    ) async {
      final data = snapshot.data();
      if (data != null && data.containsKey("activeCall")) {
        final answerSdp = data['activeCall']['answer'] as String?;
        if (answerSdp != null) {
          await peerConnection.setRemoteDescription(
            RTCSessionDescription(answerSdp, 'answer'),
          );
        }
      }
    });
  }

  Future<MediaStream> _createLocalStream(CallType type) async {
    return navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': type == CallType.video,
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _roomSubscription?.cancel();
    _cleanupCallResources();
    // TODO: implement dispose
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>(
  (ref) => CallNotifier(),
);
