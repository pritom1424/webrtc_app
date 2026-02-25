import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String loginId;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.name,
    required this.loginId,
    this.fcmToken,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      loginId: data['loginId'] ?? '',
      fcmToken: data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'loginId': loginId,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? loginId,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      loginId: loginId ?? this.loginId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
