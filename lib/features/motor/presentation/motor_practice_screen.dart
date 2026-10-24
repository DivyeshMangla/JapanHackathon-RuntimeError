import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/motor_repository_providers.dart';
import 'controllers/motor_controllers.dart';
import 'motor_demo.dart';

/// The child watches the guide, draws on paper, and a grown-up sends a
/// photo of the paper to the therapist.
class MotorPracticeScreen extends ConsumerStatefulWidget {
  const MotorPracticeScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<MotorPracticeScreen> createState() =>
      _MotorPracticeScreenState();
}

class _MotorPracticeScreenState extends ConsumerState<MotorPracticeScreen> {
  Uint8List? _photo;

  // A new id per photo; a retry of the same photo reuses it, so the
  // service counts it once.
  String _submissionId = const Uuid().v4();
  bool _working = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on AppFailure catch (failure) {
      _error = l10n.failureMessage(failure);
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _pick({bool camera = false}) => _run(() async {
    final picker = ref.read(motorPhotoPickerProvider);
    final photo = await (camera ? picker.capture() : picker.pick());
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _submissionId = const Uuid().v4();
    });
  });

  Future<void> _send(String planId) => _run(() async {
    final l10n = context.l10n;
    await ref
        .read(motorActionsProvider)
        .submit(
          childId: ref.read(currentUserProvider).id,
          planId: planId,
          exerciseId: widget.exerciseId,
          submissionId: _submissionId,
          photo: _photo!,
        );
    if (!mounted) return;
    await showCelebration(context, message: l10n.drawingSent);
    if (mounted) context.pop();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final child = ref.watch(currentUserProvider);
    final exercises = ref.watch(motorExercisesProvider).value;
    final record = ref.watch(motorRecordProvider(child.id)).value;
    final exercise = exercises
        ?.where((e) => e.id == widget.exerciseId)
        .firstOrNull;
    final planId = record?.planId;
    return ActionPage(
      title: exercise?.name ?? l10n.drawingTitle,
      intro: l10n.motorPracticeIntro,
      onBack: _working ? null : () => context.pop(),
      backLabel: l10n.back,
      error: _error,
      actions: [
        SecondaryButton(
          label: _photo == null ? l10n.motorTakePhoto : l10n.motorRetakePhoto,
          icon: LucideIcons.camera,
          onPressed: _working ? null : () => _pick(camera: true),
        ),
        SecondaryButton(
          label: _photo == null ? l10n.motorChoosePhoto : l10n.drawingNewPhoto,
          icon: LucideIcons.camera,
          onPressed: _working ? null : _pick,
        ),
        if (_photo != null && planId != null)
          PrimaryButton(
            label: _working ? l10n.drawingSending : l10n.motorSendPhoto,
            icon: LucideIcons.send,
            onPressed: _working ? null : () => _send(planId),
          ),
      ],
      children: [
        InfoNotice(l10n.motorComfort),
        if (exercise == null)
          const Skeleton(height: AppSizes.signaturePad)
        else
          MotorDemo(exercise: exercise),
        Text(l10n.motorPhotoInstructions),
        if (_photo != null) _PhotoPreview(photo: _photo!),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) => Image.memory(
    photo,
    cacheWidth: AppSizes.photoPreviewPixels,
    height: AppSizes.qrCode,
    fit: BoxFit.contain,
    semanticLabel: context.l10n.motorOriginalPhoto,
    errorBuilder: (_, _, _) => Text(context.l10n.motorInvalidPhoto),
  );
}
