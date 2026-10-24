import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/child_setup_screen.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/auth/presentation/parent_sign_up_screen.dart';
import 'package:melo/features/auth/presentation/welcome_screen.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/motor/domain/motor.dart';
import 'package:melo/features/motor/presentation/controllers/motor_controllers.dart';
import 'package:melo/features/parent/presentation/controllers/family_controllers.dart';
import 'package:melo/features/parent/presentation/parent_home_screen.dart';
import 'package:melo/features/patient/presentation/child_home_screen.dart';

final _today = dateOnly(DateTime.now());

User _user(String id, UserRole role, String name) => User(
  id: id,
  role: role,
  name: name,
  email: '',
  createdAt: _today,
  parentId: role == UserRole.patient ? 'parent' : null,
);

final _child = _user('child', UserRole.patient, 'Ananya');
final _parent = _user('parent', UserRole.parent, 'Priya Rao');

PatientActivity _nothingAssigned() => PatientActivity(
  today: _today,
  schedules: const [],
  exercises: const {},
  completions: const [],
  days: Adherence.daily(
    schedules: const [],
    completions: const [],
    from: addDays(_today, 1 - historyDays),
    to: _today,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double width = 320,
  double scale = 2,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, screen) in [
    ('welcome', const WelcomeScreen()),
    ('parent sign-up', const ParentSignUpScreen()),
    ('child setup', const ChildSetupScreen()),
  ]) {
    testWidgets('$name fits a narrow phone with enlarged text', (tester) async {
      await _pump(tester, screen);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('parent sign-up shows inline messages for empty fields', (
    tester,
  ) async {
    await _pump(tester, const ParentSignUpScreen(), width: 390, scale: 1);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Fill in this field.'), findsOneWidget);
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 10 characters.'), findsOneWidget);
  });

  testWidgets('child home greets the child with three picture buttons', (
    tester,
  ) async {
    await _pump(
      tester,
      const ChildHomeScreen(),
      overrides: [
        currentUserProvider.overrideWithValue(_child),
        patientActivityProvider.overrideWith(
          (ref, id) async => _nothingAssigned(),
        ),
        motorRecordProvider.overrideWith(
          (ref, id) async => const MotorRecord(
            planId: 'plan',
            exerciseIds: ['motor-lines'],
            submissions: [],
            consented: true,
          ),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Hi, Ananya!'), findsOneWidget);
    for (final tile in ['Games', 'Say a word', 'Drawing']) {
      expect(find.bySemanticsLabel(RegExp('^$tile')), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Drawing, 0 of 1 done'), findsOneWidget);
  });

  testWidgets('parent home asks for consent until it is signed', (
    tester,
  ) async {
    await _pump(
      tester,
      const ParentHomeScreen(),
      overrides: [
        currentUserProvider.overrideWithValue(_parent),
        familyChildrenProvider.overrideWith((ref) async => [_child]),
        childConsentProvider.overrideWith((ref, id) async => null),
        patientActivityProvider.overrideWith(
          (ref, id) async => _nothingAssigned(),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ananya'), findsOneWidget);
    expect(find.text('Sign consent'), findsOneWidget);
  });
}
