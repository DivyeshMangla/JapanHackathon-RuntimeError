/// Accounts created by the care service's demo seed (`npm run demo`), so a
/// developer can try every role on one device. Debug builds only.
enum DemoAccount { child, parent, therapist, admin }

abstract final class DemoAccounts {
  static const password = 'VoiceDemo!2026';
  static const parentEmail = 'parent@melo.test';
  static const therapistEmail = 'meera@melo.test';
  static const adminEmail = 'admin@melo.test';
  static const parentCode = 'PARENT';
  static const childName = 'Ananya';
}
