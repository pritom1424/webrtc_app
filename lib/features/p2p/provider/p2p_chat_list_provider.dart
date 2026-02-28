import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/features/p2p/model/p2p_chat_list_model.dart';
import 'package:webrtc_app/features/p2p/model/p2p_chat_model.dart';

class P2PChatListNotifier extends StreamNotifier<List<P2PListUserModel>> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Stream<List<P2PListUserModel>> build() {
    final myUid = _auth.currentUser?.uid;

    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => P2PListUserModel.fromDoc(doc))
              .where((user) => user.uid != myUid) // exclude self
              .toList(),
        );
  }

  // Create or get existing P2P chat with a user
  Future<P2PChatModel?> addChat(P2PListUserModel targetUser) async {
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

final p2pChatsProvider =
    StreamNotifierProvider<P2PChatListNotifier, List<P2PListUserModel>>(
      P2PChatListNotifier.new,
    );

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
