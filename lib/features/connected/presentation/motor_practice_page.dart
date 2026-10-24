import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../data/connected_service.dart';
import '../data/motor_photo_picker.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';
import 'motor_demo.dart';

class MotorPracticePage extends StatefulWidget {
  const MotorPracticePage({
    super.key,
    required this.service,
    required this.planId,
    required this.exercise,
    this.photoPicker = const MotorPhotoPicker(),
  });
  final ConnectedService service;
  final String planId;
  final LibraryExercise exercise;
  final MotorPhotoPicker photoPicker;
  @override
  State<MotorPracticePage> createState() => _MotorPracticePageState();
}

class _MotorPracticePageState extends State<MotorPracticePage>
    with ConnectedActions {
  Uint8List? _photo;
  String _submissionId = const Uuid().v4();
  bool _saved = false;
  @override
  ConnectedService get service => widget.service;

  Future<void> _pick() async {
    final photo = await widget.photoPicker.pick();
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _submissionId = const Uuid().v4();
      _saved = false;
    });
  }

  Future<void> _submit() async {
    await service.submitMotorPhoto(
      submissionId: _submissionId,
      planId: widget.planId,
      exerciseId: widget.exercise.id,
      photo: _photo!,
      practiceDay: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionPage(
      title: widget.exercise.name,
      intro: l10n.motorPracticeIntro,
      onBack: busy ? null : () => Navigator.pop(context),
      backLabel: l10n.connectedBack,
      error: error,
      actions: [
        if (!_saved)
          SecondaryButton(
            label: label('pick', l10n.motorChoosePhoto),
            onPressed: action('pick', _pick),
          ),
        if (_photo != null && !_saved)
          PrimaryButton(
            label: label('upload', l10n.motorSendPhoto),
            onPressed: action('upload', _submit),
          ),
        if (_saved)
          PrimaryButton(
            label: l10n.motorDone,
            onPressed: () => Navigator.pop(context),
          ),
      ],
      children: [
        InfoNotice(l10n.motorComfort),
        MotorDemo(exercise: widget.exercise),
        Text(l10n.motorPhotoInstructions),
        if (_photo != null)
          Image.memory(
            _photo!,
            height: AppSizes.qrCode,
            fit: BoxFit.contain,
            semanticLabel: l10n.motorOriginalPhoto,
            errorBuilder: (_, _, _) => Text(l10n.motorInvalidPhoto),
          ),
        if (_saved) InfoNotice(l10n.motorPhotoSaved),
      ],
    );
  }
}
