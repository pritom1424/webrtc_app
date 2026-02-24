import 'package:cloud_firestore/cloud_firestore.dart';

class P2PMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? timestamp;

  const P2PMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.timestamp,
  });

  factory P2PMessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return P2PMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
