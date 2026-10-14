import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worship_loop/main.dart';

void main() {
  testWidgets('shows the portrait mixer preview and key selector', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipLoopApp());

    expect(find.text('Worship Loop'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('GLOBAL KEY'), findsOneWidget);
    expect(find.text('C Major'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Pad 1'), 250);
    expect(find.text('Pad 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Percussion 1'), 250);
    expect(find.text('Percussion 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('SMOOTH TEMPO TRANSITION'), 250);
    expect(find.text('SMOOTH TEMPO TRANSITION'), findsOneWidget);
  });

  testWidgets('uses a compact three-column mixer in landscape', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipLoopApp());

    expect(find.text('Worship Loop'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('PADS'), findsOneWidget);
    expect(find.text('Pad 1'), findsOneWidget);
    expect(find.text('Pad 3'), findsOneWidget);
    expect(find.text('PERCUSSION'), findsOneWidget);
    expect(find.text('Perc 1'), findsOneWidget);
    expect(find.text('Perc 3'), findsOneWidget);
    expect(find.text('TEMPO TRANSITION'), findsOneWidget);
    expect(find.text('MASTER'), findsOneWidget);
  });
}
