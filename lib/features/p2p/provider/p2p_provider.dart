import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/features/p2p/model/p2p_chat_model.dart';

// ── User Model ────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String name;

  const UserModel({required this.uid, required this.name});

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(uid: doc.id, name: data['name'] ?? 'Unknown');
  }
}

// ── P2P Notifier ──────────────────────────────────────────────
// Streams all users except self
// addChat creates a p2pChat document between two users

class P2PNotifier extends StreamNotifier<List<UserModel>> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Stream<List<UserModel>> build() {
    final myUid = _auth.currentUser?.uid;
    log('P2PNotifier: streaming all users');

    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromDoc(doc))
              .where((user) => user.uid != myUid) // exclude self
              .toList(),
        );
  }

  // Create or get existing P2P chat with a user
  Future<P2PChatModel?> addChat(UserModel targetUser) async {
    try {
      final myUid = _auth.currentUser?.uid;
      if (myUid == null) throw Exception('User not authenticated');

      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myName = myDoc.data()?['name'] ?? 'Unknown';

      final chatId = P2PChatModel.generateChatId(myUid, targetUser.uid);
      final chatRef = _firestore.collection('p2pChats').doc(chatId);

      final existing = await chatRef.get();
      if (existing.exists) {
        return P2PChatModel.fromDoc(existing);
      }

      // Create new chat
      await chatRef.set({
        'participants': [myUid, targetUser.uid],
        'participantNames': {myUid: myName, targetUser.uid: targetUser.name},
        'createdAt': FieldValue.serverTimestamp(),
      });

      final created = await chatRef.get();
      return P2PChatModel.fromDoc(created);
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      return null;
    }
  }
}

final p2pProvider = StreamNotifierProvider<P2PNotifier, List<UserModel>>(
  P2PNotifier.new,
);

// ── My Chats Provider ─────────────────────────────────────────
// Streams all P2P chats the current user is part of
// Used to check if a chat already exists with a user

final myP2PChatsProvider = StreamProvider<List<P2PChatModel>>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('p2pChats')
      .where('participants', arrayContains: myUid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => P2PChatModel.fromDoc(d)).toList());
});
