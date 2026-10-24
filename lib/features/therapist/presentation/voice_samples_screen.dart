import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_list.dart';
import '../../recordings/domain/recording.dart';
import '../../recordings/presentation/analysis_chip.dart';
import '../../recordings/presentation/recording_tile.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';

/// Filter choices for the voice sample list; null means "all".
typedef _Filters = ({
  String? patientId,
  RecordingKind? kind,
  RecordingTask? task,
  RecordingType? type,
});

/// Read-only list of caseload recordings, filterable by participant, kind,
/// task and type. Therapists can listen but not edit or delete.
class VoiceSamplesScreen extends ConsumerStatefulWidget {
  const VoiceSamplesScreen({super.key, this.initialPatientId});

  final String? initialPatientId;

  @override
  ConsumerState<VoiceSamplesScreen> createState() => _VoiceSamplesScreenState();
}

class _VoiceSamplesScreenState extends ConsumerState<VoiceSamplesScreen> {
  late _Filters _filters = (
    patientId: widget.initialPatientId,
    kind: null,
    task: null,
    type: null,
  );

  bool _matches((ParticipantSummary, Recording) entry) {
    final (participant, recording) = entry;
    return (_filters.patientId == null ||
            participant.patient.id == _filters.patientId) &&
        (_filters.kind == null || recording.kind == _filters.kind) &&
        (_filters.task == null || recording.task == _filters.task) &&
        (_filters.type == null || recording.type == _filters.type);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caseload = ref.watch(caseloadProvider).value ?? const [];
    final recordings = ref.watch(caseloadRecordingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navVoiceSamples)),
      body: AsyncView(
        value: recordings,
        data: (all) {
          final shown = all.where(_matches).toList();
          return PageList(
            children: [
              _FilterPanel(
                caseload: caseload,
                filters: _filters,
                onChanged: (filters) => setState(() => _filters = filters),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.recordingCount(shown.length, all.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (shown.isEmpty)
                EmptyState(
                  icon: LucideIcons.micOff,
                  title: l10n.noMatchingRecordingsTitle,
                  message: l10n.noMatchingRecordingsBody,
                )
              else
                for (final (participant, recording) in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RecordingTile(
                      recording: recording,
                      participantCode: participant.code,
                      trailing: AnalysisChip(recording: recording),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.caseload,
    required this.filters,
    required this.onChanged,
  });

  final List<ParticipantSummary> caseload;
  final _Filters filters;
  final ValueChanged<_Filters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = filters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.filterParticipant),
        ChoicePills<String?>(
          options: [null, for (final p in caseload) p.patient.id],
          selected: f.patientId,
          labelOf: (id) => id == null
              ? l10n.filterAll
              : caseload.firstWhere((p) => p.patient.id == id).code,
          onSelected: (id) => onChanged((
            patientId: id,
            kind: f.kind,
            task: f.task,
            type: f.type,
          )),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(l10n.filterKind),
        ChoicePills<RecordingKind?>(
          options: const [null, ...RecordingKind.values],
          selected: f.kind,
          labelOf: (k) => k == null ? l10n.filterAll : l10n.kindLabel(k),
          onSelected: (k) => onChanged((
            patientId: f.patientId,
            kind: k,
            task: f.task,
            type: f.type,
          )),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(l10n.filterTask),
        ChoicePills<RecordingTask?>(
          options: const [null, ...RecordingTask.values],
          selected: f.task,
          labelOf: (t) => t == null ? l10n.filterAll : l10n.taskLabel(t),
          onSelected: (t) => onChanged((
            patientId: f.patientId,
            kind: f.kind,
            task: t,
            type: f.type,
          )),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(l10n.filterType),
        ChoicePills<RecordingType?>(
          options: const [null, ...RecordingType.values],
          selected: f.type,
          labelOf: (t) => t == null ? l10n.filterAll : l10n.typeLabel(t),
          onSelected: (t) => onChanged((
            patientId: f.patientId,
            kind: f.kind,
            task: f.task,
            type: t,
          )),
        ),
      ],
    );
  }
}
