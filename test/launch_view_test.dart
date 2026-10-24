import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_tokens.dart';
import 'package:melo/shared/widgets/launch_view.dart';
import 'package:melo/shared/widgets/melo_logo.dart';

void main() {
  testWidgets('launch view centres the full logo at the native splash size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LaunchApp());
    await tester.pumpAndSettle();

    final logo = find.byType(MeloLogo);
    expect(tester.getSize(logo).width, AppSizes.launchLogo);
    expect(tester.getCenter(logo), const Offset(195, 422));
    expect(find.bySemanticsLabel('Melo'), findsOneWidget);
  });
}
