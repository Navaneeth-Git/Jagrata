import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String title;
  final String description;
  final String severity;
  final String department;
  final String? state;
  final DateTime timestamp;
  final String status;
  final String userId;
  final String officerName;

  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.department,
    this.state,
    required this.timestamp,
    required this.status,
    required this.userId,
    required this.officerName,
  });

  factory Incident.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Incident(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      severity: data['severity'] ?? '',
      department: data['department'] ?? '',
      state: data['state'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'Pending',
      userId: data['userId'] ?? '',
      officerName: data['officerName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'severity': severity,
      'department': department,
      'state': state,
      'timestamp': timestamp,
      'status': status,
      'userId': userId,
      'officerName': officerName,
    };
  }

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? '',
      department: json['department'] ?? '',
      state: json['state'],
      timestamp: json['timestamp'] as DateTime,
      status: json['status'] ?? 'Pending',
      userId: json['userId'] ?? '',
      officerName: json['officerName'] ?? '',
    );
  }
} 