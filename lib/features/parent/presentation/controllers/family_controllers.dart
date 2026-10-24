import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository_providers.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/family_repository_providers.dart';
import '../../domain/consent.dart';

/// The signed-in parent's children, by name.
final familyChildrenProvider = FutureProvider<List<User>>((ref) async {
  final parent = ref.watch(currentUserProvider);
  final children = await ref
      .watch(userRepositoryProvider)
      .listByRole(UserRole.patient);
  return [
    for (final child in children)
      if (child.parentId == parent.id) child,
  ]..sort((a, b) => a.name.compareTo(b.name));
});

/// One of the signed-in parent's children, or null for anyone else's, so a
/// typed URL cannot open another family's child.
final familyChildProvider = FutureProvider.family<User?, String>((
  ref,
  childId,
) async {
  final children = await ref.watch(familyChildrenProvider.future);
  return children.where((child) => child.id == childId).firstOrNull;
});

/// The signed-in account's therapist, by name.
final familyTherapistProvider = FutureProvider<User?>((ref) async {
  final therapistId = ref.watch(currentUserProvider).therapistId;
  if (therapistId == null) return null;
  return ref.watch(userByIdProvider(therapistId).future);
});

final consentFormProvider = FutureProvider<ConsentForm>(
  (ref) => ref.watch(familyRepositoryProvider).consentForm(),
);

final childConsentProvider = FutureProvider.family<ChildConsent?, String>(
  (ref, childId) => ref.watch(familyRepositoryProvider).consentFor(childId),
);

final familyActionsProvider = Provider<FamilyActions>(FamilyActions.new);

class FamilyActions {
  FamilyActions(this._ref);

  final Ref _ref;

  Future<void> addChild({
    required String childName,
    required String signerName,
    required Set<ConsentStatement> agreed,
    required List<int> signaturePng,
  }) async {
    final form = await _ref.read(consentFormProvider.future);
    await _ref
        .read(familyRepositoryProvider)
        .addChild(
          childName: childName,
          version: form.version,
          signerName: signerName,
          agreed: agreed,
          signaturePng: signaturePng,
        );
    _ref.invalidate(familyChildrenProvider);
  }
}
