enum CallType { audio, video }

enum CallStatus { calling, connected, ended }

// ─────────────────────────────────────────────────────────────
// CALL MODEL
// Mirrors CallModel from original
// ─────────────────────────────────────────────────────────────

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType type;
  final String roomId;
  final CallStatus status;
  final DateTime startTime;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.type,
    required this.roomId,
    required this.status,
    required this.startTime,
  });
  CallModel copyWith({CallStatus? status}) {
    return CallModel(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      receiverId: receiverId,
      receiverName: receiverName,
      type: type,
      roomId: roomId,
      status: status ?? this.status,
      startTime: startTime,
    );
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      callId: json['callId'] ?? '',
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? '',
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      type: json['type'] == 'CallType.video' ? CallType.video : CallType.audio,
      roomId: json['roomId'] ?? '',
      status: _parseStatus(json['status']),
      startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'type': type.toString(),
      'roomId': roomId,
      'status': status.toString(),
      'startTime': startTime.toIso8601String(),
    };
  }

  static CallStatus _parseStatus(String? status) {
    switch (status) {
      case 'CallStatus.connected':
        return CallStatus.connected;
      case 'CallStatus.ended':
        return CallStatus.ended;
      default:
        return CallStatus.calling;
    }
  }
}
