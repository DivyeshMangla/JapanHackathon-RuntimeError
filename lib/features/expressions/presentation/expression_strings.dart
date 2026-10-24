import '../domain/expression.dart';

abstract final class ExpressionStrings {
  static const adultHelp = 'Will an adult help read the choices?';
  static const independent = 'Without adult help';
  static const withHelp = 'With adult help';
  static const title = 'Feelings';
  static const introduction =
      'Look at the illustrated face. Tap the feeling the picture is designed to show.';
  static const parentGuidance =
      'An adult can read the choices aloud without suggesting an answer. Take a break whenever needed.';
  static const waiting =
      'Your therapist will choose some feelings to practise here.';
  static const consentNeeded =
      'Your parent and therapist need to complete consent before practice.';
  static const start = 'Start a round';
  static const next = 'Next picture';
  static const send = 'Send my answers';
  static const sending = 'Sending…';
  static const retry = 'Try sending again';
  static const finish =
      'You finished the round. Send your answers to your therapist.';
  static const sent = 'Your therapist received your round.';
  static const history = 'Practice and therapist feedback';
  static const noSessions =
      'Completed rounds and your therapist’s remarks will appear here.';
  static const caution =
      'This score counts matching labels for these illustrated pictures. It is not a diagnosis or a measure of how a child feels or understands people in daily life.';
  static const feedback = 'Therapist’s next steps';
  static const awaiting = 'Waiting for your therapist’s feedback.';
  static const choose = 'Choose feelings for practice';
  static const chooseHelp =
      'Choose at least two feelings. Each round includes two different illustrations of each selected feeling.';
  static const enabled = 'Enable feelings practice';
  static const save = 'Save practice';
  static const saving = 'Saving…';
  static const saved = 'Practice saved';
  static const reviewed = 'Feedback sent to child and parent';
  static const feedbackLabel = 'What went well and what to practise next';
  static const feedbackHint =
      'Give a short, kind, specific next step for the family.';
  static const sendFeedback = 'Send feedback to family';
  static const feedbackRequired = 'Add feedback before sending.';
  static const details = 'Picture answers';
  static const byFeeling = 'Matches by feeling';
  static const confusions = 'Labels to practise';
  static const allMatched = 'All picture labels matched this round.';
  static const leaveTitle = 'Leave this round?';
  static const leaveMessage =
      'Answers in this round have not been sent. Stay here to finish or retry sending.';
  static const stay = 'Keep practising';
  static const leave = 'Leave round';
  static const startAgain = 'Another round';

  static String label(Feeling feeling) => switch (feeling) {
    Feeling.happy => 'Happy',
    Feeling.sad => 'Sad',
    Feeling.angry => 'Angry',
    Feeling.surprised => 'Surprised',
    Feeling.scared => 'Scared',
    Feeling.calm => 'Calm',
  };
  static String question(int index, int total) => 'Picture $index of $total';
  static String pictureLabel(int index) => 'Illustrated face, picture $index';
  static String score(int correct, int total, double accuracy) =>
      '$correct of $total picture labels matched (${accuracy.toStringAsFixed(0)}%)';
  static String count(Feeling feeling, int correct, int total) =>
      '${label(feeling)}: $correct of $total';
  static String confusion(Feeling expected, Feeling selected, int count) =>
      '${label(expected)} pictures labelled ${label(selected)}: $count';
  static String answer(Feeling expected, Feeling selected) =>
      'Picture label: ${label(expected)}. Answer: ${label(selected)}.';
}
