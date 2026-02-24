import 'package:cloud_firestore/cloud_firestore.dart';

class P2PChatModel {
  final String chatId;
  final List<String> participants;
  final Map<String, String> participantNames; // uid → name
  final DateTime? createdAt;

  const P2PChatModel({
    required this.chatId,
    required this.participants,
    required this.participantNames,
    this.createdAt,
  });

  factory P2PChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return P2PChatModel(
      chatId: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // Get chat partner's name given current uid
  String partnerName(String myUid) {
    final partnerId = participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
    return participantNames[partnerId] ?? 'Unknown';
  }

  // Get chat partner's uid given current uid
  String partnerId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  bool hasParticipant(String uid) => participants.contains(uid);

  // Deterministic chatId from two uids — always same regardless of order
  static String generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
