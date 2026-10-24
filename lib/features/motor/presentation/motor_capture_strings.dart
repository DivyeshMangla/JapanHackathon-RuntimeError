import '../domain/motor.dart';

abstract final class MotorCaptureStrings {
  static const checking = 'Checking the photo';
  static const savedPending =
      'Your photo is saved. We are still checking that the drawing is visible. Check again shortly.';
  static const checkAgain = 'Check my photo';
  static const instructions =
      'Include the whole drawing. Keep the camera steady and use a light nearby. A grown-up can help.';
  static const replaceTitle = 'Please send another photo';

  static String retake(MotorRetakeReason reason) => switch (reason) {
    MotorRetakeReason.unrelatedPhoto =>
      'Please take or choose a photo of your drawing on paper, then send it again.',
    MotorRetakeReason.unreadablePhoto =>
      'We could not clearly see the drawing. Please take another photo with the whole drawing visible, steady and in good light.',
  };
}
