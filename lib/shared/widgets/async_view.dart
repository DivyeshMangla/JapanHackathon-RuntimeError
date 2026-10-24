import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/errors/app_failure.dart';
import '../../core/utils/l10n.dart';
import 'empty_state.dart';
import 'skeleton.dart';

/// Renders an [AsyncValue] with skeleton loading and a plain error state.
/// Keeps showing previous data while a provider refreshes.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading = const SkeletonList(),
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading,
      error: (error, _) => EmptyState(
        icon: LucideIcons.triangleAlert,
        title: context.l10n.errorTitle,
        message: error is AppFailure
            ? context.l10n.failureMessage(error)
            : context.l10n.errorMessage,
      ),
    );
  }
}
