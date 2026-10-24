import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Page frame for step-by-step flows: the title and content scroll on the
/// page wash, and the page's actions sit in a white panel at the bottom so
/// the next step stays within thumb reach however long the content is.
class ActionPage extends StatelessWidget {
  const ActionPage({
    super.key,
    required this.title,
    required this.children,
    this.intro,
    this.actions = const [],
    this.error,
    this.onBack,
    this.backLabel,
    this.headerAction,
    this.backgroundColor,
  });

  final String title;
  final String? intro;
  final List<Widget> children;
  final List<Widget> actions;

  /// The last action's failure, announced and shown above the actions.
  final String? error;
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? headerAction;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasPanel = actions.isNotEmpty || error != null;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: !hasPanel,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  _PageHeader(
                    title: title,
                    intro: intro,
                    onBack: onBack,
                    backLabel: backLabel,
                    headerAction: headerAction,
                  ),
                  for (final child in children)
                    _ContentWidth(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: child,
                      ),
                    ),
                ],
              ),
            ),
            if (hasPanel) _ActionPanel(error: error, actions: actions),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    this.intro,
    this.onBack,
    this.backLabel,
    this.headerAction,
  });

  final String title;
  final String? intro;
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _ContentWidth(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null || headerAction != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        tooltip: backLabel,
                        onPressed: onBack,
                        icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      ),
                    const Spacer(),
                    ?headerAction,
                  ],
                ),
              ),
            Semantics(
              header: true,
              child: Text(title, style: text.headlineLarge),
            ),
            if (intro != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  intro!,
                  style: text.bodyLarge?.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.error, required this.actions});

  final String? error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.base),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            offset: Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.md + bottomInset,
        ),
        child: _ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ErrorMessage(error!),
                ),
              for (final (index, action) in actions.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.sm),
                  child: action,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleAlert, size: 20, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caps content at a reading width on tablets, centred.
class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.readingWidth),
        // Full width, so short content starts at the left edge instead of
        // being centred with the column.
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// A short explanation with a leading icon, for guidance that is not an
/// error.
class InfoNotice extends StatelessWidget {
  const InfoNotice(this.message, {super.key, this.icon = LucideIcons.info});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.wash),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// Marks study text that still awaits ethics approval, so it cannot be
/// mistaken for final wording during a demonstration.
class PlaceholderNotice extends StatelessWidget {
  const PlaceholderNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.triangleAlert, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Capsule naming a status; [highlighted] marks one that needs action.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.sunshine : AppColors.washTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
