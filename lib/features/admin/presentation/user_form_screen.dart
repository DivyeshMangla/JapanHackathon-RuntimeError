import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/account_validators.dart';
import 'controllers/admin_controllers.dart';

/// Creates a parent or therapist account. Children join from their
/// parent's code instead.
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _therapistId;
  InvalidInputFailure? _problem;
  bool _saving = false;

  bool get _isParent => widget.role == UserRole.parent;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final fieldsValid = _form.currentState!.validate();
    if (!fieldsValid) return;
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      final user = await ref
          .read(adminActionsProvider)
          .createUser(
            role: widget.role,
            name: _name.text,
            email: _email.text,
            password: _password.text,
            therapistId: _therapistId,
          );
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.createdUser(user.name))));
      context.pop();
    } on InvalidInputFailure catch (failure) {
      setState(() {
        _saving = false;
        _problem = failure;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final problem = _problem;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isParent ? l10n.addParent : l10n.addTherapist),
      ),
      body: Form(
        key: _form,
        child: PageList(
          children: [
            _AccountFields(name: _name, email: _email, password: _password),
            if (_isParent) ...[
              const SizedBox(height: AppSpacing.lg),
              _TherapistPicker(
                selected: _therapistId,
                onSelected: (id) => setState(() => _therapistId = id),
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.failureMessage(problem),
                style: text.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? l10n.creatingAccount : l10n.createAccount,
              icon: LucideIcons.check,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFields extends StatelessWidget {
  const _AccountFields({
    required this.name,
    required this.email,
    required this.password,
  });

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          label: l10n.fullName,
          controller: name,
          textInputAction: TextInputAction.next,
          validator: (v) => requiredName(l10n, v),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.loginEmail,
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) => validEmail(l10n, v),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.temporaryPassword,
          controller: password,
          obscureText: true,
          validator: (v) => validPassword(l10n, v),
        ),
      ],
    );
  }
}

class _TherapistPicker extends ConsumerWidget {
  const _TherapistPicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final therapists =
        ref.watch(usersByRoleProvider(UserRole.therapist)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.therapistSection),
        ChoicePills<String>(
          options: [for (final t in therapists) t.id],
          selected: selected ?? '',
          labelOf: (id) => therapists.firstWhere((t) => t.id == id).name,
          onSelected: onSelected,
        ),
      ],
    );
  }
}
