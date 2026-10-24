import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:melo/core/routing/role_shell.dart';
import 'package:melo/core/theme/app_colors.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/presentation/login_screen.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Login fits at $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppColors.pageGradient,
                  ),
                  child: child!,
                ),
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(2));
        await tester.ensureVisible(fields.first);
        await tester.enterText(fields.first, 'patient@example.org');
        expect(find.text('patient@example.org'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('capsule navigation switches all five branches at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const labels = ['Home', 'Exercises', 'Record', 'Progress', 'Profile'];
    final router = GoRouter(
      initialLocation: '/tab0',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => RoleShell(
            shell: shell,
            destinations: [
              for (final label in labels)
                NavigationDestination(
                  icon: const Icon(Icons.circle_outlined),
                  label: label,
                ),
            ],
          ),
          branches: [
            for (var i = 0; i < labels.length; i++)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/tab$i',
                    builder: (context, state) =>
                        Scaffold(body: Center(child: Text('Screen $i'))),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(find.byTooltip(labels[i]));
      await tester.pumpAndSettle();
      expect(find.text('Screen $i'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
