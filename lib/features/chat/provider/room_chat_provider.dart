import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/features/chat/model/message_model.dart';

class ChatNotifier extends StreamNotifier<List<MessageModel>> {
  final String roomId;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  ChatNotifier(this.roomId);

  @override
  Stream<List<MessageModel>> build() {
    log('ChatNotifier: building stream for room $roomId');

    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      log('Sending to room: $roomId');

      // Member check — same as original ChatBloc
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final roomData = roomDoc.data()!;

      final members = List<String>.from(roomData['members'] ?? []);
      if (!members.contains(user.uid)) {
        throw Exception('You must be a member of this room to send messages');
      }

      // Get name from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final senderName =
          userDoc.data()?['name'] ?? user.email ?? 'Unknown User';

      // Same fields as original ChatBloc
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .add({
            'text': message.trim(),
            'senderId': user.uid,
            'senderName': senderName,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = AsyncError(e, st);
    }
  }
}

final chatProvider =
    StreamNotifierProvider.family<ChatNotifier, List<MessageModel>, String>(
      (roomId) => ChatNotifier(roomId),
    );
final roomMembersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
      return FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .snapshots()
          .asyncMap((roomSnap) async {
            final memberIds = List<String>.from(
              roomSnap.data()?['members'] ?? [],
            );

            if (memberIds.isEmpty) return [];

            final usersSnap = await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: memberIds)
                .get();

            return usersSnap.docs
                .map((d) => {'uid': d.id, ...d.data()})
                .toList();
          });
    });
