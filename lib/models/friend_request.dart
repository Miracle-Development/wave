import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequest {
  final String id;
  final String fromId;
  final String fromName;
  final DateTime createdAt;
  final bool used;
  final String? usedBy;
  final DateTime? acceptedAt;

  FriendRequest({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.createdAt,
    this.used = false,
    this.usedBy,
    this.acceptedAt,
  });

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'fromName': fromName,
        'createdAt': createdAt,
        'used': used,
        'usedBy': usedBy,
        'acceptedAt': acceptedAt,
      };

  factory FriendRequest.fromJson(String id, Map<String, dynamic> json) =>
      FriendRequest(
        id: id,
        fromId: json['fromId'] as String,
        fromName: json['fromName'] as String,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        used: json['used'] as bool? ?? false,
        usedBy: json['usedBy'] as String?,
        acceptedAt: json['acceptedAt'] != null
            ? (json['acceptedAt'] as Timestamp).toDate()
            : null,
      );
}