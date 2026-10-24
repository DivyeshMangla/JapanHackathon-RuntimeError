/// [patient] is the child doing the practice; [parent] looks after them.
enum UserRole { patient, parent, therapist, admin }

/// Profile record shared by all roles. A child carries a participant code
/// (e.g. P001), their therapist and their parent. Therapists and parents
/// carry the link code others enter to join them.
class User {
  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.createdAt,
    this.participantCode,
    this.therapistId,
    this.parentId,
    this.parentName,
    this.linkCode,
  });

  final String id;
  final UserRole role;
  final String name;
  final String email;
  final DateTime createdAt;
  final String? participantCode;
  final String? therapistId;
  final String? parentId;

  /// Only filled in where the service lists a child with their parent.
  final String? parentName;

  /// A therapist's code is given to parents; a parent's code sets up the
  /// child's device.
  final String? linkCode;

  String get firstName => name.split(' ').first;

  User copyWith({String? therapistId}) => User(
    id: id,
    role: role,
    name: name,
    email: email,
    createdAt: createdAt,
    participantCode: participantCode,
    therapistId: therapistId ?? this.therapistId,
    parentId: parentId,
    parentName: parentName,
    linkCode: linkCode,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'role': role.name,
    'name': name,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'participantCode': participantCode,
    'therapistId': therapistId,
    'parentId': parentId,
    'parentName': parentName,
    'linkCode': linkCode,
  };

  factory User.fromMap(Map<dynamic, dynamic> map) => User(
    id: map['id'] as String,
    role: UserRole.values.byName(map['role'] as String),
    name: map['name'] as String,
    email: map['email'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    participantCode: map['participantCode'] as String?,
    therapistId: map['therapistId'] as String?,
    parentId: map['parentId'] as String?,
    parentName: map['parentName'] as String?,
    linkCode: map['linkCode'] as String?,
  );
}
