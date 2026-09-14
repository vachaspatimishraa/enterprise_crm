import 'lead_source.dart';
import 'lead_status.dart';

class Lead {
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final LeadStatus? status;
  final LeadSource source;
  final String? assignedUserId;
  final String? assignedUserName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lead({
    required this.id,
    this.name,
    this.phone,
    this.email,
    this.status,
    this.source = LeadSource.manual,
    this.assignedUserId,
    this.assignedUserName,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAssigned =>
      assignedUserId != null && assignedUserId!.trim().isNotEmpty;

  Lead copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    LeadStatus? status,
    LeadSource? source,
    String? assignedUserId,
    String? assignedUserName,
    bool clearAssignedUser = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      source: source ?? this.source,
      assignedUserId: clearAssignedUser
          ? null
          : (assignedUserId ?? this.assignedUserId),
      assignedUserName: clearAssignedUser
          ? null
          : (assignedUserName ?? this.assignedUserName),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lead &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          email == other.email &&
          status == other.status &&
          source == other.source &&
          assignedUserId == other.assignedUserId &&
          assignedUserName == other.assignedUserName &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    email,
    status,
    source,
    assignedUserId,
    assignedUserName,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Lead(id: $id, name: $name, phone: $phone, status: $status, source: $source, assignedTo: $assignedUserName)';
}
