import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name;
  final List<String> members;
  final DateTime? createdAt;

  const RoomModel({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
  });

  factory RoomModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      name: data['name'] as String,
      members: List<String>.from(data['members'] as List),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool isMember(String uid) => members.contains(uid);
}
