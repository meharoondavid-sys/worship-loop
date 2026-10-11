import 'package:flutter_test/flutter_test.dart';
import 'package:worship_loop/main.dart';

void main() {
  testWidgets('shows the Worship Loop mixer preview', (tester) async {
    await tester.pumpWidget(const WorshipLoopApp());

    expect(find.text('Worship Loop'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('Pad 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Percussion 1'), 250);
    expect(find.text('Percussion 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('SMOOTH TEMPO TRANSITION'), 250);
    expect(find.text('SMOOTH TEMPO TRANSITION'), findsOneWidget);
  });
}
