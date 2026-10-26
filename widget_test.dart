import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worship_loop/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the portrait mixer and all six track controls',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipLoopApp());
    await tester.pumpAndSettle();

    expect(find.text('WORSHIP LOOP'), findsOneWidget);
    expect(find.text('Stage Mixer'), findsOneWidget);
    expect(find.text('GLOBAL KEY'), findsOneWidget);
    expect(find.text('C Major'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('STOP ALL'), findsOneWidget);
    expect(find.text('AMBIENT PADS'), findsOneWidget);
    expect(find.text('PERCUSSION'), findsOneWidget);

    for (final label in [
      'Pad 1',
      'Pad 2',
      'Pad 3',
      'Percussion 1',
      'Percussion 2',
      'Percussion 3',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('shows all six channels simultaneously in landscape without scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipLoopApp());
    await tester.pumpAndSettle();

    expect(find.text('WORSHIP LOOP'), findsOneWidget);
    expect(find.text('Stage Mixer'), findsOneWidget);
    expect(find.text('GLOBAL KEY'), findsOneWidget);
    expect(find.text('C Major'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('STOP ALL'), findsOneWidget);
    expect(find.text('AMBIENT PADS'), findsOneWidget);
    expect(find.text('PERCUSSION'), findsOneWidget);

    // In landscape, all six channel strips are rendered simultaneously on screen
    for (final label in [
      'Pad 1',
      'Pad 2',
      'Pad 3',
      'Percussion 1',
      'Percussion 2',
      'Percussion 3',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('handles compact phone landscape dimensions without error',
      (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorshipLoopApp());
    await tester.pumpAndSettle();

    expect(find.text('WORSHIP LOOP'), findsOneWidget);
    expect(find.text('STOP ALL'), findsOneWidget);
    expect(find.text('AMBIENT PADS'), findsOneWidget);
    expect(find.text('PERCUSSION'), findsOneWidget);

    for (final label in [
      'Pad 1',
      'Pad 2',
      'Pad 3',
      'Percussion 1',
      'Percussion 2',
      'Percussion 3',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
