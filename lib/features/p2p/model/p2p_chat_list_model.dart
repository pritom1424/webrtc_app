import 'package:cloud_firestore/cloud_firestore.dart';

class P2PListUserModel {
  final String uid;
  final String name;

  const P2PListUserModel({required this.uid, required this.name});

  factory P2PListUserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return P2PListUserModel(uid: doc.id, name: data['name'] ?? 'Unknown');
  }
}
