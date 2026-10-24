import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usage_event.dart';
import 'controllers/usage_controllers.dart';

/// Records one usage event when [child] is first shown, for screens whose
/// use matters to the usage log (exercise instructions, education).
class UsageTracker extends ConsumerStatefulWidget {
  const UsageTracker({
    super.key,
    required this.action,
    required this.detail,
    required this.child,
  });

  final UsageAction action;
  final String detail;
  final Widget child;

  @override
  ConsumerState<UsageTracker> createState() => _UsageTrackerState();
}

class _UsageTrackerState extends ConsumerState<UsageTracker> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(usageLoggerProvider)
          .record(widget.action, detail: widget.detail),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
