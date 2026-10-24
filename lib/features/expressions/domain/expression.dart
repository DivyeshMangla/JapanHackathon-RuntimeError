enum ExpressionAssistance { independent, withHelp }

enum Feeling { happy, sad, angry, surprised, scared, calm }

class ExpressionPicture {
  const ExpressionPicture(this.feeling, this.variant);

  final Feeling feeling;
  final int variant;
  String get id => '${feeling.name}-$variant';

  static ExpressionPicture fromId(String id) {
    final parts = id.split('-');
    return ExpressionPicture(
      Feeling.values.byName(parts.first),
      int.parse(parts.last),
    );
  }
}

class ExpressionAssignment {
  ExpressionAssignment({
    required this.id,
    required List<Feeling> feelings,
    required this.enabled,
  }) : feelings = List.unmodifiable(feelings);

  final String id;
  final List<Feeling> feelings;
  final bool enabled;
  List<ExpressionPicture> get pictures => [
    for (final feeling in feelings) ...[
      ExpressionPicture(feeling, 1),
      ExpressionPicture(feeling, 2),
    ],
  ];
}

class ExpressionAnswer {
  const ExpressionAnswer({required this.pictureId, required this.selected});
  final String pictureId;
  final Feeling selected;
}

class ExpressionItem {
  const ExpressionItem({
    required this.pictureId,
    required this.expected,
    required this.selected,
    required this.correct,
  });
  final String pictureId;
  final Feeling expected;
  final Feeling selected;
  final bool correct;
}

class FeelingCount {
  const FeelingCount({
    required this.feeling,
    required this.correct,
    required this.total,
  });
  final Feeling feeling;
  final int correct;
  final int total;
}

class ExpressionConfusion {
  const ExpressionConfusion({
    required this.expected,
    required this.selected,
    required this.count,
  });
  final Feeling expected;
  final Feeling selected;
  final int count;
}

class ExpressionSession {
  ExpressionSession({
    required this.id,
    required this.assignmentId,
    required this.createdAt,
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.assistance,
    required List<FeelingCount> perExpression,
    required List<ExpressionConfusion> confusions,
    required List<ExpressionItem> items,
    this.reviewNote,
    this.reviewedAt,
    this.reviewedBy,
  }) : perExpression = List.unmodifiable(perExpression),
       confusions = List.unmodifiable(confusions),
       items = List.unmodifiable(items);

  final String id;
  final String assignmentId;
  final DateTime createdAt;
  final int correct;
  final int total;
  final double accuracy;
  final ExpressionAssistance assistance;
  final List<FeelingCount> perExpression;
  final List<ExpressionConfusion> confusions;
  final List<ExpressionItem> items;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final String? reviewedBy;
}

class ExpressionRecord {
  ExpressionRecord({
    required this.assignment,
    required this.consented,
    required List<ExpressionSession> sessions,
  }) : sessions = List.unmodifiable(sessions);

  final ExpressionAssignment? assignment;
  final bool consented;
  final List<ExpressionSession> sessions;
}
