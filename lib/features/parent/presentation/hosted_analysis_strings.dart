abstract final class HostedAnalysisStrings {
  static const title = 'Optional online analysis';
  static const on = 'Online analysis is on for this child.';
  static const off = 'Online analysis is off for this child.';
  static const explanation =
      'With your permission, Groq can analyze practice photos and voice '
      'recordings for the therapist. Practice and therapist feedback '
      'are available either way.';
  static const careConsentRequired =
      'Approved care consent is needed before you can choose online analysis.';
  static const saving = 'Saving…';
  static const turnOff = 'Turn off online analysis';
  static const review = 'Review online analysis permission';
  static const guardianConfirmation =
      'I am this child’s parent or guardian and allow online analysis.';
  static const keepOff = 'Keep it off';
  static const allow = 'Allow online analysis';
  static String privacyInformation(String url) =>
      'Provider privacy information: $url';
}
