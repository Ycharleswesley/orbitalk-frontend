import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  ringing,
  ongoing,
  ended,
  missed,
  declined,
  cancelled,
  busy
}

enum CallType {
  incoming,
  outgoing
}

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final CallType callType;
  final CallStatus callStatus;
  final DateTime timestamp;
  final int duration;
  final String? channelId;
  final bool callerViewed;
  final bool receiverViewed;
  final int callerProfileColor;   // Added
  final int receiverProfileColor; // Added

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    required this.callType,
    required this.callStatus,
    required this.timestamp,
    this.duration = 0,
    this.channelId,
    this.callerViewed = true,
    this.receiverViewed = false,
    this.callerProfileColor = 0,   // Default Blue
    this.receiverProfileColor = 0, // Default Blue
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'callType': callType.name,
      'callStatus': callStatus.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration,
      'channelId': channelId,
      'callerViewed': callerViewed,
      'receiverViewed': receiverViewed,
      'callerProfileColor': callerProfileColor,
      'receiverProfileColor': receiverProfileColor,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    return CallModel(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? 'Unknown',
      callerAvatar: map['callerAvatar'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? 'Unknown',
      receiverAvatar: map['receiverAvatar'] ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.name == map['callType'],
        orElse: () => CallType.outgoing,
      ),
      callStatus: CallStatus.values.firstWhere(
        (e) => e.name == map['callStatus'],
        orElse: () => CallStatus.ended,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: map['duration'] ?? 0,
      channelId: map['channelId'],
      callerViewed: map['callerViewed'] ?? true,
      receiverViewed: map['receiverViewed'] ?? true, // Default true for legacy
      callerProfileColor: map['callerProfileColor'] ?? 0,
      receiverProfileColor: map['receiverProfileColor'] ?? 0,
    );
  }

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
    CallType? callType,
    CallStatus? callStatus,
    DateTime? timestamp,
    int? duration,
    String? channelId,
    bool? callerViewed,
    bool? receiverViewed,
    int? callerProfileColor,
    int? receiverProfileColor,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      callType: callType ?? this.callType,
      callStatus: callStatus ?? this.callStatus,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      channelId: channelId ?? this.channelId,
      callerViewed: callerViewed ?? this.callerViewed,
      receiverViewed: receiverViewed ?? this.receiverViewed,
      callerProfileColor: callerProfileColor ?? this.callerProfileColor,
      receiverProfileColor: receiverProfileColor ?? this.receiverProfileColor,
    );
  }
}
