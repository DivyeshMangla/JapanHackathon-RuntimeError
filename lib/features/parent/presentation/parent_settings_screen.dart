import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/link_code_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'controllers/family_controllers.dart';
import 'practice_reminders.dart';

/// The parent's code for setting up the child's device, their therapist,
/// practice reminders on this phone, and sign out.
class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final parent = ref.watch(currentUserProvider);
    final therapist = ref.watch(familyTherapistProvider).value;
    final code = parent.linkCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: PageList(
        children: [
          if (code != null)
            LinkCodeCard(
              title: l10n.parentCodeTitle,
              code: code,
              message: l10n.parentCodeHowTo,
            ),
          if (therapist != null) ...[
            const SizedBox(height: AppSpacing.md),
            InkCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.stethoscope),
                title: Text(therapist.name),
                subtitle: Text(l10n.parentYourTherapist),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.parentReminders),
          Text(
            l10n.parentRemindersHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          PracticeReminders(userId: parent.id),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: l10n.signOut,
            icon: LucideIcons.logOut,
            onPressed: () => runWithFailureMessage(
              context,
              () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
