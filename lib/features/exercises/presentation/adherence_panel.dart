import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/ink_card.dart';
import '../domain/adherence.dart';
import 'completion_chart.dart';

enum _Range { daily, weekly }

/// Daily or weekly completion chart with a table view of the same numbers.
/// [days] is daily history ending today, as in `PatientActivity.days`.
class AdherencePanel extends StatefulWidget {
  const AdherencePanel({super.key, required this.days});

  final List<AdherencePeriod> days;

  @override
  State<AdherencePanel> createState() => _AdherencePanelState();
}

class _AdherencePanelState extends State<AdherencePanel> {
  _Range _range = _Range.daily;
  bool _showTable = false;

  @override
  Widget build(BuildContext context) {
    final daily = lastPeriods(widget.days, 14);
    final weekly = lastPeriods(Adherence.weekly(widget.days), 8);
    final isDaily = _range == _Range.daily;
    final l10n = context.l10n;
    final periods = isDaily ? daily : weekly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoicePills<_Range>(
          options: _Range.values,
          selected: _range,
          labelOf: (r) =>
              r == _Range.daily ? l10n.rangeDaily : l10n.rangeWeekly,
          onSelected: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: AppSpacing.md),
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: CompletionChart(
            key: ValueKey(_range),
            periods: periods,
            axisLabel: isDaily
                ? (p) => formatWeekdayInitial(p.start)
                : (p) => '${p.start.day}/${p.start.month}',
            detailLabel: isDaily
                ? (p) => formatDayMonth(p.start)
                : (p) => l10n.weekOf(formatShortDate(p.start)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showTable = !_showTable),
            icon: Icon(
              _showTable ? LucideIcons.chevronUp : LucideIcons.table,
              size: 18,
            ),
            label: Text(_showTable ? l10n.hideTable : l10n.showTable),
          ),
        ),
        if (_showTable) _PeriodTable(periods: periods, weekly: !isDaily),
      ],
    );
  }
}

/// The last [count] entries of [periods], or all of them if there are fewer.
List<AdherencePeriod> lastPeriods(List<AdherencePeriod> periods, int count) =>
    periods.sublist(periods.length > count ? periods.length - count : 0);

class _PeriodTable extends StatelessWidget {
  const _PeriodTable({required this.periods, required this.weekly});

  final List<AdherencePeriod> periods;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final today = dateOnly(DateTime.now());
    return InkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final p in periods.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      weekly
                          ? l10n.weekOf(formatShortDate(p.start))
                          : p.start == today
                          ? l10n.homeToday
                          : formatDayMonth(p.start),
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    p.due == 0 ? l10n.restDay : '${p.done} / ${p.due}',
                    style: text.bodySmall,
                  ),
                  SizedBox(
                    width: AppSizes.valueColumn,
                    child: Text(
                      formatPercent(p.rate),
                      textAlign: TextAlign.right,
                      style: text.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
