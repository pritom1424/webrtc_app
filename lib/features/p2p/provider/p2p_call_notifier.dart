import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/core/services/notification_service.dart';
import 'package:webrtc_app/features/p2p/model/p2p_call_state.dart';

class P2PCallNotifier extends StateNotifier<P2PCallState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _lastShownCallKey;
  String? _watchedChatId;

  StreamSubscription? _chatSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _candidatesSubscription;
  StreamSubscription? _offerSubscription;

  P2PCallNotifier() : super(P2PCallState.initial());

  void watchChat(String chatId) {
    if (_watchedChatId == chatId && _chatSubscription != null) return;

    _chatSubscription?.cancel();
    _watchedChatId = chatId;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _chatSubscription = _firestore
        .collection('p2pChats')
        .doc(chatId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          final activeCall = data['activeCall'] as Map<String, dynamic>?;

          if (activeCall == null) {
            if (state.isIncoming || state.isActive) {
              print('📵 activeCall deleted — cleaning up');
              _cleanupResources();
              state = P2PCallState.initial();
            }
            return;
          }

          final callStatus = activeCall['status'] as String?;

          // P2P ONLY: detect ended/rejected/cancelled so other side auto-disconnects
          if (callStatus == 'ended' ||
              callStatus == 'rejected' ||
              callStatus == 'cancelled') {
            if (state.isIncoming || state.isActive) {
              print('📵 Call $callStatus — cleaning up');
              _cleanupResources();
              state = P2PCallState.initial();
              _firestore.collection('p2pChats').doc(chatId).update({
                'activeCall': FieldValue.delete(),
              });
            }
            return;
          }

          final callerId = activeCall['callerId'] as String?;
          final callerName = activeCall['callerName'] as String? ?? 'Someone';
          final startedAtTs = activeCall['startedAt'] as Timestamp?;

          if (startedAtTs == null) return;

          final callKey = '${callerId}_${startedAtTs.seconds}';

          if (callerId == uid) return;
          if (state.isActive) return;
          if (_lastShownCallKey == callKey) return;

          if (callStatus == 'calling') {
            print('📞 Incoming P2P call: $callKey from $callerName');
            _lastShownCallKey = callKey;
            state = state.copyWith(
              status: P2PCallStatus.incoming,
              chatId: chatId,
              callerName: callerName,
              isVideo: activeCall['isVideo'] as bool? ?? true,
              peerId: callerId,
              peerName: callerName,
            );
          }
        });
  }

  Future<void> startCall({
    required String chatId,
    required String peerId,
    required String peerName,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final uid = currentUser.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final myName = userDoc.data()?['name'] ?? 'Unknown';

      await _firestore.collection('p2pChats').doc(chatId).update({
        'activeCall': {
          'callerId': uid,
          'callerName': myName,
          'startedAt': FieldValue.serverTimestamp(),
          'status': 'calling',
          'isVideo': isVideo,
        },
      });
      // Notify receiver
      await NotificationService.instance.sendToUser(
        recipientUid: peerId,
        title: '$myName is calling...',
        body: isVideo ? '📹 Incoming video call' : '📞 Incoming audio call',
        data: {'type': isVideo ? 'video_call' : 'call', 'chatId': chatId},
      );

      await _joinInternal(
        chatId: chatId,
        peerId: peerId,
        peerName: peerName,
        isVideo: isVideo,
        myId: uid,
        myName: myName,
        amICaller: true,
      );
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
      await cancelCall();
    }
  }

  Future<void> acceptCall({
    required String chatId,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final uid = currentUser.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final myName = userDoc.data()?['name'] ?? 'Unknown';

      final peerId = state.peerId;
      final peerName = state.peerName;
      if (peerId == null) throw Exception('No caller id');

      await _joinInternal(
        chatId: chatId,
        peerId: peerId,
        peerName: peerName ?? '',
        isVideo: isVideo,
        myId: uid,
        myName: myName,
        amICaller: false,
      );
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
      state = P2PCallState.initial();
    }
  }

  // Caller connects to peer; receiver watches for caller's offer

  Future<void> _joinInternal({
    required String chatId,
    required String peerId,
    required String peerName,
    required bool isVideo,
    required String myId,
    required String myName,
    required bool amICaller,
  }) async {
    // Clean up stale signaling from previous call — same as conference rejoin
    await _cleanupSignaling(chatId: chatId, myId: myId);
    // Only receiver watches for offer — caller sends it

    final localStream = await _createLocalStream(isVideo);

    await _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('call')
        .doc(myId)
        .set({
          'userId': myId,
          'name': myName,
          'joinedAt': FieldValue.serverTimestamp(),
        });

    await Future.delayed(const Duration(milliseconds: 500));

    state = state.copyWith(
      status: P2PCallStatus.active,
      chatId: chatId,
      isVideo: isVideo,
      localStream: localStream,
      peerId: peerId,
      peerName: peerName,
      clearRemoteStream: true,
    );

    if (amICaller) {
      await _connectToPeer(chatId: chatId, myId: myId, peerId: peerId);
    } else {
      _watchOfferFromPeer(chatId: chatId, myId: myId, peerId: peerId);
    }
  }

  Future<void> _connectToPeer({
    required String chatId,
    required String myId,
    required String peerId,
  }) async {
    if (state.peerConnection != null) return;

    final pc = await _createPeerConnection();
    pc.onConnectionState = (s) => print('🔗 P2P caller connection: $s');
    pc.onIceConnectionState = (s) => print('🧊 P2P caller ICE: $s');
    // 1 Set onTrack FIRST
    pc.onTrack = (RTCTrackEvent event) {
      print('🎥 Caller onTrack fired — streams: ${event.streams.length}');
      if (event.streams.isNotEmpty) {
        print('🎥 Caller received remote track');
        state = state.copyWith(remoteStream: event.streams[0]);
      }
    };

    // 2 Local ICE candidate handler
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _firestore
          .collection('p2pChats')
          .doc(chatId)
          .collection('call')
          .doc(myId)
          .collection('candidatesFor')
          .doc(peerId)
          .collection('items')
          .add({
            ...candidate.toMap(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    };
    print('🔍 _connectToPeer — localStream: ${state.localStream}');
    print(
      '🔍 _connectToPeer — tracks: ${state.localStream?.getTracks().length}',
    );
    // 3 Add local tracks AFTER onTrack
    state.localStream?.getTracks().forEach((track) {
      pc.addTrack(track, state.localStream!);
    });

    state = state.copyWith(peerConnection: pc);

    // 4 Start listening for answer BEFORE creating offer
    _listenForAnswer(chatId: chatId, myId: myId, peerId: peerId, pc: pc);
    _listenForCandidates(chatId: chatId, myId: myId, peerId: peerId, pc: pc);

    // 5 Create offer and set local description
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('call')
        .doc(myId)
        .collection('offersFor')
        .doc(peerId)
        .set({'sdp': offer.sdp, 'type': offer.type, 'ready': true});
  }

  Future<void> _checkAndAnswerOffer({
    required String chatId,
    required String myId,
    required String peerId,
  }) async {
    if (state.peerConnection != null) return; // already connected

    try {
      final offerDoc = await _firestore
          .collection('p2pChats')
          .doc(chatId)
          .collection('call')
          .doc(peerId)
          .collection('offersFor')
          .doc(myId)
          .get();

      if (!offerDoc.exists) return;
      final ready = offerDoc.data()?['ready'] as bool? ?? false;
      if (!ready) return;
      final offerSdp = offerDoc.data()?['sdp'] as String?;
      if (offerSdp == null) return;

      if (state.peerConnection != null) return; // race condition guard
      print('🔍 _checkAndAnswerOffer — localStream: ${state.localStream}');
      print(
        '🔍 _checkAndAnswerOffer — tracks: ${state.localStream?.getTracks().length}',
      );

      final pc = await _createPeerConnection();

      pc.onConnectionState = (s) => print('🔗 P2P receiver state: $s');
      pc.onIceConnectionState = (s) => print('🧊 P2P receiver ICE: $s');

      pc.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          print('🎥 P2P receiver got remote stream');
          state = state.copyWith(remoteStream: event.streams[0]);
        }
      };

      pc.onIceCandidate = (RTCIceCandidate candidate) {
        _firestore
            .collection('p2pChats')
            .doc(chatId)
            .collection('call')
            .doc(myId)
            .collection('candidatesFor')
            .doc(peerId)
            .collection('items')
            .add(candidate.toMap());
      };

      state.localStream?.getTracks().forEach((track) {
        pc.addTrack(track, state.localStream!);
      });

      state = state.copyWith(peerConnection: pc);

      await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      print(
        '🔍 Receiver tracks added: ${state.localStream?.getTracks().length}',
      );
      print('🔍 Receiver senders: ${(await pc.senders).length}');

      await _firestore
          .collection('p2pChats')
          .doc(chatId)
          .collection('call')
          .doc(myId)
          .collection('answersFor')
          .doc(peerId)
          .set({'sdp': answer.sdp, 'type': answer.type});

      _listenForCandidates(chatId: chatId, myId: myId, peerId: peerId, pc: pc);
    } catch (e) {
      print('Error answering offer from $peerId: $e');
    }
  }

  void _watchOfferFromPeer({
    required String chatId,
    required String myId,
    required String peerId,
  }) {
    _offerSubscription?.cancel();
    _offerSubscription = _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('call')
        .doc(peerId)
        .collection('offersFor')
        .doc(myId)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;
          final ready = snapshot.data()?['ready'] as bool? ?? false;
          if (!ready) return;
          if (state.peerConnection != null) return;
          await _checkAndAnswerOffer(
            chatId: chatId,
            myId: myId,
            peerId: peerId,
          );
        });
  }

  void _listenForAnswer({
    required String chatId,
    required String myId,
    required String peerId,
    required RTCPeerConnection pc,
  }) {
    _answerSubscription?.cancel();
    print('👂 Setting up answer listener at: call/$peerId/answersFor/$myId');
    _answerSubscription = _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('call')
        .doc(peerId)
        .collection('answersFor')
        .doc(myId)
        .snapshots()
        .listen((snapshot) async {
          print('👂 Answer snapshot fired — exists: ${snapshot.exists}');
          if (!snapshot.exists) return;
          final answerSdp = snapshot.data()?['sdp'] as String?;
          if (answerSdp == null) return;
          await pc.setRemoteDescription(
            RTCSessionDescription(answerSdp, 'answer'),
          );
          var t = await pc.getRemoteDescription();
          print("call sdp receive");
          print(t?.sdp.toString());
          print('📋 Caller remote desc set: ${pc.connectionState}');
        });
  }

  void _listenForCandidates({
    required String chatId,
    required String myId,
    required String peerId,
    required RTCPeerConnection pc,
  }) {
    final listenStartTime = DateTime.now();
    _candidatesSubscription?.cancel();
    _candidatesSubscription = _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('call')
        .doc(peerId)
        .collection('candidatesFor')
        .doc(myId)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              // Skip candidates that existed before we started this call
              final ts = change.doc.data()?['timestamp'] as Timestamp?;
              if (ts != null && ts.toDate().isBefore(listenStartTime)) {
                //  print(' Skipping stale candidate');
                continue;
              }
              final data = change.doc.data()!;

              pc.addCandidate(
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

  // P2P needs to notify the other side

  Future<void> endCall() async {
    final chatId = state.chatId;
    final uid = _auth.currentUser?.uid;

    try {
      if (chatId != null && uid != null) {
        await _cleanupSignaling(chatId: chatId, myId: uid);
        if (state.peerId != null) {
          await _cleanupSignaling(chatId: chatId, myId: state.peerId!);
        }
        // Signal other side
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall.status': 'ended',
        });
        await Future.delayed(const Duration(milliseconds: 300));
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall': FieldValue.delete(),
        });
      }
      _cleanupResources();

      state = P2PCallState.initial();
    } catch (e) {
      print('endCall error: $e');
    }
  }

  Future<void> cancelCall() async {
    final chatId = state.chatId;

    try {
      if (chatId != null) {
        if (state.peerId != null) {
          await _cleanupSignaling(chatId: chatId, myId: state.peerId!);
        }
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall.status': 'cancelled',
        });
        await Future.delayed(const Duration(milliseconds: 300));
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall': FieldValue.delete(),
        });
      }
      _cleanupResources();
      await Future.delayed(const Duration(milliseconds: 100));
      state = P2PCallState.initial();
    } catch (e) {
      print('cancelCall error: $e');
    }
  }

  Future<void> rejectCall() async {
    final chatId = state.chatId;

    try {
      if (chatId != null) {
        if (state.peerId != null) {
          await _cleanupSignaling(chatId: chatId, myId: state.peerId!);
        }
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall.status': 'rejected',
        });
        await Future.delayed(const Duration(milliseconds: 300));
        await _firestore.collection('p2pChats').doc(chatId).update({
          'activeCall': FieldValue.delete(),
        });
      }
      _cleanupResources();
      state = P2PCallState.initial();
    } catch (e) {
      print('rejectCall error: $e');
    }
  }

  Future<MediaStream> _createLocalStream(bool isVideo) async {
    return await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    return await createPeerConnection({
      "iceServers": [
        {
          "urls": [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
            "stun:stun.relay.metered.ca:80",
          ],
        },
        {
          "urls": "turn:global.relay.metered.ca:80",
          "username": "4d1027cc3008d5b50b3a778b",
          "credential": "rntBwHiqwdQasZLA",
        },
        {
          "urls": "turn:global.relay.metered.ca:80?transport=tcp",
          "username": "4d1027cc3008d5b50b3a778b",
          "credential": "rntBwHiqwdQasZLA",
        },
        {
          "urls": "turn:global.relay.metered.ca:443",
          "username": "4d1027cc3008d5b50b3a778b",
          "credential": "rntBwHiqwdQasZLA",
        },
        {
          "urls": "turns:global.relay.metered.ca:443?transport=tcp",
          "username": "4d1027cc3008d5b50b3a778b",
          "credential": "rntBwHiqwdQasZLA",
        },
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
    });
  }

  Future<void> _cleanupSignaling({
    required String chatId,
    required String myId,
  }) async {
    try {
      final myCallRef = _firestore
          .collection('p2pChats')
          .doc(chatId)
          .collection('call')
          .doc(myId);

      final offers = await myCallRef.collection('offersFor').get();
      for (final doc in offers.docs) await doc.reference.delete();
      final answers = await myCallRef.collection('answersFor').get();
      for (final doc in answers.docs) await doc.reference.delete();
      final cands = await myCallRef.collection('candidatesFor').get();
      for (final doc in cands.docs) {
        final items = await doc.reference.collection('items').get();
        for (final item in items.docs) await item.reference.delete();
        await doc.reference.delete();
      }
      await myCallRef.delete();
    } catch (e) {
      print('_cleanupSignaling error: $e');
    }
  }

  void _cleanupResources() {
    _offerSubscription?.cancel();
    _answerSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _offerSubscription = null;
    _answerSubscription = null;
    _candidatesSubscription = null;
    // Remove all senders before disposing
    state.peerConnection?.senders.then((senders) {
      for (final sender in senders) {
        state.peerConnection?.removeTrack(sender);
      }
    });
    state.peerConnection?.dispose();
    // Stop all tracks explicitly before disposing — releases camera/mic indicator
    state.localStream?.getTracks().forEach((track) => track.stop());
    state.localStream?.dispose();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _cleanupResources();
    super.dispose();
  }
}

final p2pCallProvider = StateNotifierProvider<P2PCallNotifier, P2PCallState>(
  (ref) => P2PCallNotifier(),
);
