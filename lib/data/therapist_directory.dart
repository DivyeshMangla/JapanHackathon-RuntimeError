abstract interface class TherapistDirectory {
  Future<Map<String, dynamic>?> resolve(String code);
  bool get nearbyActive;
}

class LocalTherapistDirectory implements TherapistDirectory {
  @override
  bool get nearbyActive => false;
  @override
  Future<Map<String, dynamic>?> resolve(String code) async => null;
}
