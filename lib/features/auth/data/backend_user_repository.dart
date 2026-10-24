import '../../../core/errors/app_failure.dart';
import '../../../core/network/backend_client.dart';
import '../domain/user.dart';
import '../domain/user_repository.dart';

User userFromApi(JsonObject json) => User(
  id: json['id']! as String,
  role: UserRole.values.byName(json['role']! as String),
  name: json['name']! as String,
  email: json['email'] as String? ?? '',
  createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
  participantCode: json['participant_code'] as String?,
  therapistId: json['therapist_id'] as String?,
  parentId: json['parent_id'] as String?,
  parentName: json['parent_name'] as String?,
  linkCode: json['link_code'] as String?,
);

/// Users as the care service lets the signed-in account see them: a child
/// sees themself, their parent and their therapist, a parent their children
/// and therapist, a therapist their caseload, an administrator everyone.
class BackendUserRepository implements UserRepository {
  BackendUserRepository(this._client);

  final BackendClient _client;
  final _known = <String, User>{};
  User? _current;

  /// Called after sign-in so lookups know whose view of the service to load.
  void remember(User user, {bool current = false}) {
    _known[user.id] = user;
    if (current) _current = user;
  }

  void forget() {
    _known.clear();
    _current = null;
  }

  @override
  Future<User?> findById(String id) async {
    final cached = _known[id];
    if (cached != null) return cached;
    await _loadVisible();
    return _known[id];
  }

  @override
  Future<List<User>> listByRole(UserRole role) async {
    await _loadVisible();
    return _sorted([
      for (final user in _known.values)
        if (user.role == role) user,
    ]);
  }

  @override
  Future<List<User>> patientsOf(String therapistId) async {
    await _loadVisible();
    return _sorted([
      for (final user in _known.values)
        if (user.role == UserRole.patient && user.therapistId == therapistId)
          user,
    ]);
  }

  @override
  Future<User> create({
    required UserRole role,
    required String name,
    required String email,
    required String password,
    String? therapistId,
  }) async {
    try {
      final response = await _client.post(
        '/users',
        body: {
          'role': role.name,
          'name': name,
          'email': email,
          'password': password,
          'therapistId': ?therapistId,
          if (role == UserRole.therapist) ...const {
            'clinic': 'Melo Therapy Clinic',
            'registration': 'Added by administrator',
          },
        },
      );
      final user = userFromApi(response.object('user'));
      remember(user);
      return user;
    } on NetworkFailure catch (failure) {
      if (failure.status == 409) {
        throw const InvalidInputFailure(InputProblem.emailTaken);
      }
      rethrow;
    }
  }

  @override
  Future<void> assignTherapist({
    required String patientId,
    required String therapistId,
  }) async {
    final response = await _client.put(
      '/patients/$patientId/assignment',
      body: {'therapistId': therapistId},
    );
    remember(userFromApi(response.object('patient')));
  }

  Future<void> _loadVisible() async {
    final role = _current?.role;
    if (role == null) return;
    if (role == UserRole.patient || role == UserRole.parent) {
      for (final json in (await _client.get('/directory')).objects('users')) {
        if (_known.containsKey(json['id'])) continue;
        remember(_directoryUser(json));
      }
      if (role == UserRole.patient) return;
    }
    final response = await _client.get(
      role == UserRole.admin ? '/users' : '/patients',
    );
    final key = role == UserRole.admin ? 'users' : 'patients';
    for (final json in response.objects(key)) {
      remember(userFromApi(json));
    }
  }

  /// The directory lists names only.
  User _directoryUser(JsonObject json) => User(
    id: json['id']! as String,
    role: UserRole.values.byName(json['role']! as String),
    name: json['name']! as String,
    email: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  static List<User> _sorted(List<User> users) => users
    ..sort(
      (a, b) => a.role == UserRole.patient
          ? (a.participantCode ?? '').compareTo(b.participantCode ?? '')
          : a.name.compareTo(b.name),
    );
}
