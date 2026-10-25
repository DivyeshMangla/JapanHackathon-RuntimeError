import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/motor/domain/motor.dart';

MotorReport _report({
  int? expected = 3,
  int? observed,
  String rating = 'developing',
}) => MotorReport(
  observations: '',
  suggestion: '',
  alignment: rating,
  formation: rating,
  spacing: 'not_assessable',
  model: 'test',
  imageQuality: 'usable',
  expectedCount: expected,
  observedCount: observed,
);

void main() {
  test('count score treats extra forms like missing ones', () {
    expect(_report(observed: 3).countScore, 1);
    expect(_report(observed: 2).countScore, closeTo(2 / 3, 1e-9));
    expect(_report(observed: 4).countScore, closeTo(2 / 3, 1e-9));
    expect(_report(observed: 9).countScore, 0);
    expect(_report(observed: null).countScore, isNull);
    expect(_report(expected: null, observed: 2).countScore, isNull);
  });

  test('ratings map to thirds and unassessable ratings have no score', () {
    expect(_report(rating: 'emerging').formationScore, closeTo(1 / 3, 1e-9));
    expect(_report(rating: 'developing').alignmentScore, closeTo(2 / 3, 1e-9));
    expect(_report(rating: 'consistent').formationScore, 1);
    expect(_report().spacingScore, isNull);
  });
}
