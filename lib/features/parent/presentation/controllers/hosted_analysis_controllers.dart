import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/backend_client.dart';
import '../../data/backend_hosted_analysis_repository.dart';
import '../../domain/hosted_analysis.dart';

final hostedAnalysisRepositoryProvider = Provider<HostedAnalysisRepository>(
  (ref) => BackendHostedAnalysisRepository(ref.watch(backendClientProvider)),
);

final hostedAnalysisPermissionProvider =
    FutureProvider.family<HostedAnalysisPermission, String>(
      (ref, childId) =>
          ref.watch(hostedAnalysisRepositoryProvider).permissionFor(childId),
    );
