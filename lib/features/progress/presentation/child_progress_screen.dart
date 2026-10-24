import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'controllers/progress_controllers.dart';
import 'progress_panel.dart';
import 'progress_strings.dart';

class ChildProgressScreen extends ConsumerWidget {
  const ChildProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(ProgressStrings.childTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyProgressProvider(child.id));
          await runWithFailureMessage(context, () async {
            await ref
                .read(familyProgressProvider(child.id).future)
                .then<void>((_) {});
          });
        },
        child: PageList(
          children: [ProgressPanel(childId: child.id, childFriendly: true)],
        ),
      ),
    );
  }
}
