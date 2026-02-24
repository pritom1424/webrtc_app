import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/features/call/model/conference_state.dart';

class ConferenceNotifier extends StateNotifier<ConferenceState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _lastShownConferenceKey;

  StreamSubscription? _membersSubscription;
  StreamSubscription? _roomSubscription;
  final Map<String, StreamSubscription> _answerSubscriptions = {};
  final Map<String, StreamSubscription> _candidateSubscriptions = {};

  ConferenceNotifier() : super(ConferenceState.initial());

  void watchRoom(String roomId) {
    _roomSubscription?.cancel();

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _roomSubscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          final activeConference =
              data['activeConference'] as Map<String, dynamic>?;

          if (activeConference == null) {
            if (state.isIncoming || state.isActive) {
              _cleanupResources();
              state = ConferenceState.initial();
            }
            return;
          }

          final conferenceStatus = activeConference['status'] as String?;
          final startedBy = activeConference['startedBy'] as String?;
          final startedByName =
              activeConference['startedByName'] as String? ?? 'Someone';
          final startedAtTs = activeConference['startedAt'] as Timestamp?;

          if (startedAtTs == null) return;

          final conferenceKey = '${startedBy}_${startedAtTs.seconds}';

          if (startedBy == uid) return;
          if (state.isActive) return;
          if (_lastShownConferenceKey == conferenceKey) return;

          if (conferenceStatus == 'active') {
            _lastShownConferenceKey = conferenceKey;
            state = state.copyWith(
              status: ConferenceStatus.incoming,
              roomId: roomId,
              startedByName: startedByName,
            );
          }
        });
  }

  Future<void> startConference({
    required String roomId,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final uid = currentUser.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final myName = userDoc.data()?['name'] ?? 'Unknown';

      await _firestore.collection('rooms').doc(roomId).update({
        'activeConference': {
          'startedBy': uid,
          'startedByName': myName,
          'startedAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'isVideo': isVideo,
        },
      });

      await _joinConferenceInternal(
        roomId: roomId,
        isVideo: isVideo,
        myId: uid,
        myName: myName,
      );
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ── Join Conference ───────────────────────────────────────

  Future<void> joinConference({
    required String roomId,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final uid = currentUser.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final myName = userDoc.data()?['name'] ?? 'Unknown';

      await _joinConferenceInternal(
        roomId: roomId,
        isVideo: isVideo,
        myId: uid,
        myName: myName,
      );
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ── Leave Conference ──────────────────────────────────────

  Future<void> leaveConference() async {
    try {
      final roomId = state.roomId;
      final uid = _auth.currentUser?.uid;

      if (roomId != null && uid != null) {
        final myConferenceRef = _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('conference')
            .doc(uid);

        final offers = await myConferenceRef.collection('offersFor').get();
        for (final doc in offers.docs) {
          await doc.reference.delete();
        }
        final answers = await myConferenceRef.collection('answersFor').get();
        for (final doc in answers.docs) {
          await doc.reference.delete();
        }
        final candidatesFor = await myConferenceRef
            .collection('candidatesFor')
            .get();
        for (final doc in candidatesFor.docs) {
          final items = await doc.reference.collection('items').get();
          for (final item in items.docs) {
            await item.reference.delete();
          }
          await doc.reference.delete();
        }

        await myConferenceRef.delete();

        final remaining = await _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('conference')
            .get();

        if (remaining.docs.isEmpty) {
          await _firestore.collection('rooms').doc(roomId).update({
            'activeConference': FieldValue.delete(),
          });

          // Wipe entire conference subcollection when last person leaves
          final allDocs = await _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('conference')
              .get();

          for (final doc in allDocs.docs) {
            final ref = doc.reference;
            for (final sub in ['offersFor', 'answersFor', 'candidatesFor']) {
              final subDocs = await ref.collection(sub).get();
              for (final subDoc in subDocs.docs) {
                if (sub == 'candidatesFor') {
                  final items = await subDoc.reference
                      .collection('items')
                      .get();
                  for (final item in items.docs) {
                    await item.reference.delete();
                  }
                }
                await subDoc.reference.delete();
              }
            }
            await ref.delete();
          }
        }
      }
      _cleanupResources();

      await Future.delayed(const Duration(milliseconds: 100));
      state = ConferenceState.initial();
    } catch (e) {
      log(e.toString());

      _cleanupResources();
      await Future.delayed(const Duration(milliseconds: 100));
      state = ConferenceState.initial();
    }
  }

  // ── Dismiss incoming ──────────────────────────────────────

  Future<void> dismissIncoming() async {
    final roomId = state.roomId ?? '';
    final uid = _auth.currentUser?.uid;

    if (roomId.isNotEmpty && uid != null) {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('conference')
          .doc(uid)
          .set({
            'userId': uid,
            'dismissed': true,
            'dismissedAt': FieldValue.serverTimestamp(),
          });
    }

    state = ConferenceState.initial();
  }

  // ── Internal join logic ───────────────────────────────────

  Future<void> _joinConferenceInternal({
    required String roomId,
    required bool isVideo,
    required String myId,
    required String myName,
  }) async {
    await _cleanupMySignaling(roomId: roomId, myId: myId);
    final localStream = await _createLocalStream(isVideo);

    // Register self — clean doc, no dismissed flag
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
        .doc(myId)
        .set({
          'userId': myId,
          'name': myName,
          'joinedAt': FieldValue.serverTimestamp(),
        });

    await Future.delayed(const Duration(milliseconds: 500));

    state = state.copyWith(
      status: ConferenceStatus.active,
      roomId: roomId,
      localStream: localStream,
      isVideo: isVideo,
    );

    // Get all existing members and connect to each as caller
    final membersSnap = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
        .get();

    for (final doc in membersSnap.docs) {
      final peerId = doc.id;
      if (peerId == myId) continue;

      // Skip dismissed peers
      final dismissed = doc.data()['dismissed'] as bool? ?? false;
      if (dismissed) continue;

      final peerName = doc.data()['name'] ?? 'Unknown';
      final updatedNames = Map<String, String>.from(state.memberNames);
      updatedNames[peerId] = peerName;
      state = state.copyWith(memberNames: updatedNames);

      await _connectToPeer(
        roomId: roomId,
        myId: myId,
        peerId: peerId,
        isCaller: true,
      );
      // Watch for their offer in case they also connect to us
      _watchOfferFromPeer(roomId: roomId, myId: myId, peerId: peerId);
    }

    // Listen for new members joining after us
    _listenForNewMembers(roomId: roomId, myId: myId);
  }

  // ── Connect to a single peer (we are caller) ─────────────

  Future<void> _connectToPeer({
    required String roomId,
    required String myId,
    required String peerId,
    required bool isCaller,
  }) async {
    try {
      if (state.peerConnections.containsKey(peerId)) {
        log('Already connected to $peerId — skipping');
        return;
      }

      final peerConnection = await _createPeerConnection();

      peerConnection.onConnectionState = (RTCPeerConnectionState s) {
        log('🔗 Connection state with $peerId: $s');
      };
      peerConnection.onIceConnectionState = (RTCIceConnectionState s) {
        log('🧊 ICE state with $peerId: $s');
      };

      state.localStream?.getTracks().forEach((track) {
        peerConnection.addTrack(track, state.localStream!);
      });

      final updatedConnections = Map<String, RTCPeerConnection>.from(
        state.peerConnections,
      );
      updatedConnections[peerId] = peerConnection;
      state = state.copyWith(peerConnections: updatedConnections);

      peerConnection.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final updatedStreams = Map<String, MediaStream>.from(
            state.remoteStreams,
          );
          updatedStreams[peerId] = event.streams[0];
          state = state.copyWith(remoteStreams: updatedStreams);
        }
      };

      peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
        // Write ICE candidates to: conference/myId/candidatesFor/peerId/items
        _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('conference')
            .doc(myId)
            .collection('candidatesFor')
            .doc(peerId)
            .collection('items')
            .add({
              ...candidate.toMap(),
              'timestamp': FieldValue.serverTimestamp(),
            });
      };

      // Create offer and write to: conference/myId/offersFor/peerId
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('conference')
          .doc(myId)
          .collection('offersFor') // ← NEW: per-peer offers collection
          .doc(peerId)
          .set({
            'sdp': offer.sdp,
            'type': offer.type,
            'ready': true, // ready flag is per-offer not per-peer-doc
          });

      log('📤 Offer written for $peerId');

      // Listen for answer at: conference/peerId/answersFor/myId
      _listenForAnswer(
        roomId: roomId,
        myId: myId,
        peerId: peerId,
        peerConnection: peerConnection,
      );

      // Listen for their ICE candidates targeting us
      _listenForCandidates(
        roomId: roomId,
        myId: myId,
        peerId: peerId,
        peerConnection: peerConnection,
      );
    } catch (e) {
      log('Error connecting to peer $peerId: $e');
    }
  }

  Future<void> _checkAndAnswerOffer({
    required String roomId,
    required String myId,
    required String peerId,
  }) async {
    // Already connected to this peer — skip
    if (state.peerConnections.containsKey(peerId)) return;

    try {
      // Check conference/peerId/offersFor/myId
      final offerDoc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('conference')
          .doc(peerId)
          .collection('offersFor')
          .doc(myId)
          .get();

      if (!offerDoc.exists) return;

      final ready = offerDoc.data()?['ready'] as bool? ?? false;
      if (!ready) return;

      final offerSdp = offerDoc.data()?['sdp'] as String?;
      if (offerSdp == null) return;

      // Double check not already connected (race condition guard)
      if (state.peerConnections.containsKey(peerId)) return;

      final peerConnection = await _createPeerConnection();

      peerConnection.onConnectionState = (RTCPeerConnectionState s) {
        log('🔗 Answer side - Connection state with $peerId: $s');
      };
      peerConnection.onIceConnectionState = (RTCIceConnectionState s) {
        log('🧊 Answer side - ICE state with $peerId: $s');
      };

      state.localStream?.getTracks().forEach((track) {
        peerConnection.addTrack(track, state.localStream!);
      });

      final updatedConnections = Map<String, RTCPeerConnection>.from(
        state.peerConnections,
      );
      updatedConnections[peerId] = peerConnection;
      state = state.copyWith(peerConnections: updatedConnections);

      peerConnection.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final updatedStreams = Map<String, MediaStream>.from(
            state.remoteStreams,
          );
          updatedStreams[peerId] = event.streams[0];
          state = state.copyWith(remoteStreams: updatedStreams);
        }
      };

      peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
        _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('conference')
            .doc(myId)
            .collection('candidatesFor')
            .doc(peerId)
            .collection('items')
            .add(candidate.toMap());
      };

      await peerConnection.setRemoteDescription(
        RTCSessionDescription(offerSdp, 'offer'),
      );

      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);

      // Write answer to: conference/myId/answersFor/peerId
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('conference')
          .doc(myId)
          .collection('answersFor') // ← NEW: per-peer answers collection
          .doc(peerId)
          .set({'sdp': answer.sdp, 'type': answer.type});

      log('📤 Answer written for $peerId');

      _listenForCandidates(
        roomId: roomId,
        myId: myId,
        peerId: peerId,
        peerConnection: peerConnection,
      );
    } catch (e) {
      log('Error answering offer from $peerId: $e');
    }
  }

  void _watchOfferFromPeer({
    required String roomId,
    required String myId,
    required String peerId,
  }) {
    final sub = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
        .doc(peerId)
        .collection('offersFor')
        .doc(myId)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;
          final ready = snapshot.data()?['ready'] as bool? ?? false;
          if (!ready) return;
          if (state.peerConnections.containsKey(peerId)) return;
          await _checkAndAnswerOffer(
            roomId: roomId,
            myId: myId,
            peerId: peerId,
          );
        });

    _candidateSubscriptions['offer_$peerId'] = sub;
  }

  // Caller listens for answer at: conference/peerId/answersFor/myId

  void _listenForAnswer({
    required String roomId,
    required String myId,
    required String peerId,
    required RTCPeerConnection peerConnection,
  }) {
    final sub = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
        .doc(peerId)
        .collection('answersFor') // ← NEW path
        .doc(myId)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;
          final answerSdp = snapshot.data()?['sdp'] as String?;
          if (answerSdp == null) return;

          final currentDesc = await peerConnection.getRemoteDescription();
          if (currentDesc != null) return;

          log('✅ Got answer from $peerId');
          await peerConnection.setRemoteDescription(
            RTCSessionDescription(answerSdp, 'answer'),
          );
        });

    _answerSubscriptions[peerId] = sub;
  }

  void _listenForCandidates({
    required String roomId,
    required String myId,
    required String peerId,
    required RTCPeerConnection peerConnection,
  }) {
    final listenStartTime = DateTime.now();
    final sub = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
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
                log('⏭️ Skipping stale candidate');
                continue;
              }
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

    _candidateSubscriptions[peerId] = sub;
  }

  void _listenForNewMembers({required String roomId, required String myId}) {
    _membersSubscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('conference')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            final peerId = change.doc.id;
            if (peerId == myId) continue;

            if (change.type == DocumentChangeType.added) {
              final dismissed =
                  change.doc.data()?['dismissed'] as bool? ?? false;
              if (dismissed) {
                log('Peer $peerId dismissed — not connecting');
                continue;
              }

              final peerName = change.doc.data()?['name'] ?? 'Unknown';
              final updatedNames = Map<String, String>.from(state.memberNames);
              updatedNames[peerId] = peerName;
              state = state.copyWith(memberNames: updatedNames);

              _watchOfferFromPeer(roomId: roomId, myId: myId, peerId: peerId);
            }

            if (change.type == DocumentChangeType.removed) {
              log('Peer left: $peerId — removing from grid');

              final updatedConnections = Map<String, RTCPeerConnection>.from(
                state.peerConnections,
              );
              final updatedStreams = Map<String, MediaStream>.from(
                state.remoteStreams,
              );
              final updatedNames = Map<String, String>.from(state.memberNames);

              updatedConnections[peerId]?.dispose();
              updatedConnections.remove(peerId);
              updatedStreams.remove(peerId);
              updatedNames.remove(peerId);

              _answerSubscriptions[peerId]?.cancel();
              _answerSubscriptions.remove(peerId);
              _candidateSubscriptions[peerId]?.cancel();
              _candidateSubscriptions.remove(peerId);

              state = state.copyWith(
                peerConnections: updatedConnections,
                remoteStreams: updatedStreams,
                memberNames: updatedNames,
              );
            }
          }
        });
  }

  // ── Helpers ───────────────────────────────────────────────

  Future<MediaStream> _createLocalStream(bool isVideo) async {
    return await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    return await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
          ],
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
      'sdpSemantics': 'unified-plan',
    });
  }

  Future<void> _cleanupMySignaling({
    required String roomId,
    required String myId,
  }) async {
    try {
      final myRef = _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('conference')
          .doc(myId);

      final offers = await myRef.collection('offersFor').get();
      for (final doc in offers.docs) await doc.reference.delete();
      final answers = await myRef.collection('answersFor').get();
      for (final doc in answers.docs) await doc.reference.delete();
      final cands = await myRef.collection('candidatesFor').get();
      for (final doc in cands.docs) {
        final items = await doc.reference.collection('items').get();
        for (final item in items.docs) await item.reference.delete();
        await doc.reference.delete();
      }
      await myRef.delete();
    } catch (e) {
      log('_cleanupMySignaling error: $e');
    }
  }

  void _cleanupResources() {
    _membersSubscription?.cancel();
    _roomSubscription?.cancel();

    for (final sub in _answerSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _candidateSubscriptions.values) {
      sub.cancel();
    }
    for (final pc in state.peerConnections.values) {
      pc.senders.then((senders) {
        for (final sender in senders) pc.removeTrack(sender);
      });
      pc.dispose();
    }
    // Stop tracks explicitly
    state.localStream?.getTracks().forEach((track) => track.stop());
    state.localStream?.dispose();
    _answerSubscriptions.clear();
    _candidateSubscriptions.clear();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }
}

final conferenceProvider =
    StateNotifierProvider<ConferenceNotifier, ConferenceState>(
      (ref) => ConferenceNotifier(),
    );

final activeConferenceProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, roomId) {
      return FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .snapshots()
          .map(
            (snap) => snap.data()?['activeConference'] as Map<String, dynamic>?,
          );
    });
