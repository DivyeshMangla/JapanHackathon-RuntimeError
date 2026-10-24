import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/seal_mark.dart';
import 'controllers/auth_controller.dart';

/// Keeps the form a comfortable reading width on tablets.
const _maxFormWidth = 440.0;

/// The headline sits on the page gradient and the form in a white panel
/// anchored to the bottom, so Sign in stays within thumb reach on tall
/// phones. Spare height goes between the header and the headline, and the
/// whole page scrolls when the keyboard or large text needs it.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                _LoginHeader(),
                SizedBox(height: AppSpacing.xl),
                Spacer(),
                _LoginHeadline(),
                _LoginPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: _FormWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            0,
          ),
          child: Row(
            children: [
              const SealMark(size: AppSizes.minTouchTarget),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  context.l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHeadline extends StatelessWidget {
  const _LoginHeadline();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final headline = text.displayLarge;
    return _FormWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        child: EntryCascade(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.loginHeadlineLead),
                  const TextSpan(text: '\n'),
                  TextSpan(
                    text: l10n.loginHeadlineEmphasis,
                    style: headline?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: headline,
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                l10n.loginIntro,
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White sheet holding the form. Fields take a grey fill here, because the
/// theme's white fill would vanish against the sheet.
class _LoginPanel extends StatelessWidget {
  const _LoginPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.base),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter,
          AppSpacing.lg + bottomInset,
        ),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              fillColor: AppColors.washTint,
            ),
          ),
          child: const _FormWidth(child: _LoginForm()),
        ),
      ),
    );
  }
}

/// Centres content at [_maxFormWidth] with side padding rather than a max
/// width box: the page is sized from intrinsic heights, and a max width box
/// would report the shorter height of text wrapped at the full width.
class _FormWidth extends StatelessWidget {
  const _FormWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spare = MediaQuery.sizeOf(context).width - _maxFormWidth;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spare > 0 ? spare / 2 : 0),
      child: child,
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscured = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = context.l10n.loginMissingFields);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final l10n = context.l10n;
    String? error;
    try {
      final signedIn = await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
      if (signedIn) return;
      error = l10n.loginFailed;
    } on AppFailure catch (failure) {
      error = l10n.failureMessage(failure);
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            label: l10n.loginEmail,
            controller: _email,
            hint: l10n.loginEmailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            prefixIcon: LucideIcons.mail,
            enabled: !_submitting,
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledTextField(
            label: l10n.loginPassword,
            controller: _password,
            obscureText: _obscured,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            prefixIcon: LucideIcons.lock,
            errorText: _error,
            enabled: !_submitting,
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              tooltip: _obscured
                  ? l10n.loginShowPassword
                  : l10n.loginHidePassword,
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              icon: Icon(
                _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 20,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _submitting ? l10n.loginSubmitting : l10n.loginSubmit,
            icon: LucideIcons.logIn,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          // There is no self-service reset, so point patients to the people
          // who manage their account.
          Text(
            l10n.loginHelp,
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          // A developer tool; release builds given to patients never show it.
          if (!kReleaseMode) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.sensorCheck),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                icon: const Icon(LucideIcons.activity, size: 16),
                label: Text(l10n.sensorCheckOpen, style: text.bodySmall),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
