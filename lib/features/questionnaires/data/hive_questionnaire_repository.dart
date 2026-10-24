import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/questionnaire.dart';

/// All three questionnaires share one box; each stored map carries a type
/// tag so they can be told apart. The tag never leaves this class.
class HiveQuestionnaireRepository implements QuestionnaireRepository {
  HiveQuestionnaireRepository(this._box);

  static const _type = 'type';
  static const _selfReport = 'selfReport';
  static const _usability = 'usability';
  static const _satisfaction = 'satisfaction';

  final Box<Map<dynamic, dynamic>> _box;

  Iterable<Map<dynamic, dynamic>> _ofType(String type, [String? patientId]) =>
      _box.values.where(
        (m) =>
            m[_type] == type &&
            (patientId == null || m['patientId'] == patientId),
      );

  List<AdherenceSelfReport> _selfReports([String? patientId]) =>
      _ofType(_selfReport, patientId).map(AdherenceSelfReport.fromMap).toList()
        ..sort((a, b) => a.week.compareTo(b.week));

  List<UsabilityResponse> _usabilityResponses([String? patientId]) =>
      _ofType(_usability, patientId).map(UsabilityResponse.fromMap).toList()
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

  List<SatisfactionResponse> _satisfactionResponses([String? patientId]) =>
      _ofType(
          _satisfaction,
          patientId,
        ).map(SatisfactionResponse.fromMap).toList()
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

  @override
  Future<QuestionnaireHistory> forPatient(String patientId) => guardStorage(
    () => QuestionnaireHistory(
      selfReports: _selfReports(patientId),
      usability: _usabilityResponses(patientId),
      satisfaction: _satisfactionResponses(patientId),
    ),
  );

  @override
  Future<List<AdherenceSelfReport>> allSelfReports() =>
      guardStorage(_selfReports);

  @override
  Future<List<UsabilityResponse>> allUsability() =>
      guardStorage(_usabilityResponses);

  @override
  Future<List<SatisfactionResponse>> allSatisfaction() =>
      guardStorage(_satisfactionResponses);

  @override
  Future<void> saveSelfReport(AdherenceSelfReport report) => guardStorage(
    () => _box.put(report.id, {...report.toMap(), _type: _selfReport}),
  );

  @override
  Future<void> saveUsability(UsabilityResponse response) => guardStorage(
    () => _box.put(response.id, {...response.toMap(), _type: _usability}),
  );

  @override
  Future<void> saveSatisfaction(SatisfactionResponse response) => guardStorage(
    () => _box.put(response.id, {...response.toMap(), _type: _satisfaction}),
  );
}
