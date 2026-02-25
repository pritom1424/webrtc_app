import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/services/notification_service.dart';
import 'package:webrtc_app/features/p2p/model/p2p_message_model.dart';

class P2PChatNotifier extends StreamNotifier<List<P2PMessageModel>> {
  final String chatId;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  P2PChatNotifier(this.chatId);

  @override
  Stream<List<P2PMessageModel>> build() {
    return _firestore
        .collection('p2pChats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => P2PMessageModel.fromDoc(d)).toList(),
        );
  }

  Future<void> sendMessage(String text) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final name = userDoc.data()?['name'] ?? 'Unknown';

      await _firestore
          .collection('p2pChats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'senderName': name,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
      // Get peer id — chatId format is uid1_uid2
      final parts = chatId.split('_');
      final peerId = parts.firstWhere((p) => p != user.uid, orElse: () => '');

      if (peerId.isNotEmpty) {
        await NotificationService.instance.sendToUser(
          recipientUid: peerId,
          title: name,
          body: text,
          data: {'type': 'message', 'chatId': chatId},
        );
      }
    } catch (e, st) {
      log(e.toString());
      log(st.toString());
      state = AsyncError(e, st);
    }
  }
}

final p2pChatProvider =
    StreamNotifierProvider.family<
      P2PChatNotifier,
      List<P2PMessageModel>,
      String
    >((chatId) => P2PChatNotifier(chatId));

// Active call stream
final p2pActiveCallProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, chatId) {
      return FirebaseFirestore.instance
          .collection('p2pChats')
          .doc(chatId)
          .snapshots()
          .map((snap) => snap.data()?['activeCall'] as Map<String, dynamic>?);
    });
