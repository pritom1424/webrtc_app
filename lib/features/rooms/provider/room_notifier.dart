import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/features/rooms/model/room_model.dart';

class RoomNotifier extends StreamNotifier<List<RoomModel>> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mirrors: _onLoadRooms — streams ALL rooms
  // Each room item knows if current user is a member via isMember()
  @override
  Stream<List<RoomModel>> build() {
    return _firestore
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => RoomModel.fromDoc(doc)).toList(),
        );
  }

  Future<void> createRoom(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      await _firestore.collection('rooms').add({
        'name': name,
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final roomRef = _firestore.collection('rooms').doc(roomId);

      await _firestore.runTransaction((transaction) async {
        final roomDoc = await transaction.get(roomRef);
        if (!roomDoc.exists) throw Exception('Room does not exist');

        final currentMembers = List<String>.from(roomDoc.get('members'));
        if (!currentMembers.contains(user.uid)) {
          currentMembers.add(user.uid);
          transaction.update(roomRef, {'members': currentMembers});
        }
      });
    } catch (e, st) {
      rethrow;
    }
  }
}

final roomProvider = StreamNotifierProvider<RoomNotifier, List<RoomModel>>(
  RoomNotifier.new,
);
