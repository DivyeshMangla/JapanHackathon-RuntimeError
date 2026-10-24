import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/connected_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../useful_words/presentation/therapist_words_page.dart';
import '../../useful_words/presentation/word_strings.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';
import 'motor_sections.dart';
import 'patient_sections.dart';

/// The server accepts plans of one to six exercises.
const _maxPlanExercises = 6;

/// One patient on the therapist's caseload: consent review, the clinical
/// assessment, the plan, and the practice and recordings that came back.
class TherapistPatientPage extends StatefulWidget {
  const TherapistPatientPage({
    super.key,
    required this.service,
    required this.patientId,
  });

  final ConnectedService service;
  final String patientId;

  @override
  State<TherapistPatientPage> createState() => _TherapistPatientPageState();
}

class _TherapistPatientPageState extends State<TherapistPatientPage>
    with ConnectedActions {
  final _assessmentForm = GlobalKey<FormState>();
  final _planForm = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _demographic = TextEditingController();
  final _clinical = TextEditingController();
  final _planTitle = TextEditingController();
  final _notes = TextEditingController();
  final _player = AudioPlayer();
  PatientRecord? _record;
  ConnectedFailure? _loadFailure;
  bool _paperCopy = false;
  Set<String> _exercises = {};
  int _sessionsPerDay = 2;
  String? _notice;

  /// The decrypted copy being played; deleted when playback stops.
  File? _playback;

  @override
  ConnectedService get service => widget.service;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in [
      _age,
      _demographic,
      _clinical,
      _planTitle,
      _notes,
    ]) {
      controller.dispose();
    }
    unawaited(_player.dispose().then((_) => _deletePlayback()));
    super.dispose();
  }

  Future<void> _load() async {
    final firstLoad = _record == null;
    try {
      final record = await service.patient(widget.patientId);
      if (!mounted) return;
      if (firstLoad) _fillForms(record);
      setState(() {
        _record = record;
        _loadFailure = null;
      });
    } on ConnectedFailure catch (failure) {
      if (mounted) setState(() => _loadFailure = failure);
    }
  }

  void _fillForms(PatientRecord record) {
    final forms = record.forms;
    if (forms != null) {
      _age.text = '${forms.age}';
      _demographic.text = forms.demographic;
      _clinical.text = forms.clinical;
    }
    _planTitle.text =
        record.plan?.title ?? context.l10n.connectedPlanTitleDefault;
    _notes.text = record.plan?.notes ?? '';
    _exercises = {...?record.plan?.exerciseIds};
    _sessionsPerDay = record.plan?.sessionsPerDay ?? _sessionsPerDay;
  }

  VoidCallback? _changeAction(
    String key,
    Future<void> Function() body, {
    bool enabled = true,
  }) => busy || !enabled ? null : () => unawaited(_change(key, body));

  /// Runs a change, then reloads so the page shows what the server stored.
  Future<void> _change(String key, Future<void> Function() body) async {
    final l10n = context.l10n;
    setState(() => _notice = null);
    final saved = await run(key, () async {
      await body();
      await _load();
    });
    if (saved && mounted) setState(() => _notice = l10n.connectedSaved);
  }

  Future<void> _saveAssessment() async {
    if (!_assessmentForm.currentState!.validate()) return;
    await service.saveForms(
      widget.patientId,
      ClinicalForms(
        age: int.parse(_age.text),
        demographic: _demographic.text.trim(),
        clinical: _clinical.text.trim(),
      ),
    );
  }

  Future<void> _savePlan() async {
    if (!_planForm.currentState!.validate()) return;
    await service.prescribe(
      widget.patientId,
      PlanDraft(
        title: _planTitle.text.trim(),
        exerciseIds: _exercises.toList(),
        sessionsPerDay: _sessionsPerDay,
        notes: _notes.text.trim(),
      ),
    );
  }

  Future<void> _play(String recordingId) async {
    await _stop();
    final bytes = await service.recordingAudio(recordingId);
    final file = File(
      '${(await getTemporaryDirectory()).path}/review-${const Uuid().v4()}.wav',
    );
    await file.writeAsBytes(bytes, flush: true);
    _playback = file;
    await _player.setFilePath(file.path);
    unawaited(_player.play());
  }

  Future<void> _stop() async {
    await _player.stop();
    await _deletePlayback();
  }

  Future<void> _deletePlayback() async {
    final file = _playback;
    _playback = null;
    if (file != null && await file.exists()) await file.delete();
  }

  Future<void> _reviewMotor(String id) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const FeedbackDialog(),
    );
    if (note == null || !mounted) return;
    await _change('motor-review', () => service.reviewMotor(id, note));
  }

  Future<void> _review(String recordingId) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const FeedbackDialog(),
    );
    if (note == null || !mounted) return;
    await _change(
      'review-$recordingId',
      () => service.reviewRecording(recordingId, note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final record = _record;
    final consent = record?.consent;
    final approved = consent?.status == ConsentStatus.approved;
    return ActionPage(
      title: record?.summary.name ?? l10n.connectedPatientTitle,
      onBack: () => Navigator.pop(context),
      backLabel: l10n.connectedBack,
      error: error,
      actions: [
        if (record == null && _loadFailure != null)
          PrimaryButton(
            label: l10n.connectedRetry,
            icon: LucideIcons.refreshCw,
            onPressed: () {
              setState(() => _loadFailure = null);
              unawaited(_load());
            },
          ),
      ],
      children: [
        if (record == null && _loadFailure == null) ...[
          const Skeleton(height: AppSizes.signaturePad),
          const Skeleton(height: AppSizes.signaturePreview),
        ] else if (record == null)
          InfoNotice(
            '${l10n.connectedPatientLoadFailed} '
            '${l10n.connectedFailureMessage(_loadFailure!)}',
            icon: LucideIcons.circleAlert,
          )
        else ...[
          SecondaryButton(
            label: WordStrings.title,
            icon: LucideIcons.messageCircle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TherapistWordsPage(
                  repository: service.wordsFor(widget.patientId),
                  childName: record.summary.name,
                ),
              ),
            ),
          ),
          if (_notice != null)
            InfoNotice(_notice!, icon: LucideIcons.circleCheck),
          ConsentSection(
            consent: consent,
            paperCopy: _paperCopy,
            onPaperCopy: busy
                ? null
                : (value) => setState(() => _paperCopy = value),
            approveLabel: label('approve', l10n.connectedApproveConsent),
            onApprove: _changeAction(
              'approve',
              () => service.approveConsent(widget.patientId),
              enabled: _paperCopy,
            ),
          ),
          if (approved)
            AssessmentSection(
              formKey: _assessmentForm,
              age: _age,
              demographic: _demographic,
              clinical: _clinical,
              enabled: !busy,
              saveLabel: label('forms', l10n.connectedSaveAssessment),
              onSave: _changeAction('forms', _saveAssessment),
            ),
          if (approved && record.forms != null)
            PlanSection(
              formKey: _planForm,
              currentPlan: record.plan,
              titleController: _planTitle,
              notesController: _notes,
              library: service.config.exercises,
              selected: _exercises,
              maxExercises: _maxPlanExercises,
              sessionsPerDay: _sessionsPerDay,
              enabled: !busy,
              onSelected: (selection) => setState(() => _exercises = selection),
              onSessionsPerDay: (value) =>
                  setState(() => _sessionsPerDay = value),
              saveLabel: label('plan', l10n.connectedSavePlan),
              onSave: _changeAction(
                'plan',
                _savePlan,
                enabled: _exercises.isNotEmpty,
              ),
            ),
          PracticeSection(record: record, library: service.config),
          MotorReviewsSection(
            service: service,
            submissions: record.motorSubmissions,
            onReview: (id) {
              if (!busy) unawaited(_reviewMotor(id));
            },
            onRetry: (id) {
              if (!busy) {
                unawaited(_change('motor-retry', () => service.retryMotor(id)));
              }
            },
          ),
          RecordingsSection(
            recordings: record.recordings,
            library: service.config,
            onPlay: (id) => action('play-$id', () => _play(id)),
            onStop: () => unawaited(_stop()),
            onReview: (id) => busy ? null : () => unawaited(_review(id)),
          ),
        ],
      ],
    );
  }
}
