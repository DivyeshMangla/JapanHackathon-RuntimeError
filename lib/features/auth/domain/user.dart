enum UserRole { patient, therapist, admin }

/// Profile record shared by all roles. Patients additionally carry a
/// participant code (e.g. P001) and the id of their assigned therapist.
class User {
  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.createdAt,
    this.participantCode,
    this.therapistId,
  });

  final String id;
  final UserRole role;
  final String name;
  final String email;
  final DateTime createdAt;
  final String? participantCode;
  final String? therapistId;

  String get firstName => name.split(' ').first;

  User copyWith({String? therapistId}) => User(
    id: id,
    role: role,
    name: name,
    email: email,
    createdAt: createdAt,
    participantCode: participantCode,
    therapistId: therapistId ?? this.therapistId,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'role': role.name,
    'name': name,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'participantCode': participantCode,
    'therapistId': therapistId,
  };

  factory User.fromMap(Map<dynamic, dynamic> map) => User(
    id: map['id'] as String,
    role: UserRole.values.byName(map['role'] as String),
    name: map['name'] as String,
    email: map['email'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    participantCode: map['participantCode'] as String?,
    therapistId: map['therapistId'] as String?,
  );
}
