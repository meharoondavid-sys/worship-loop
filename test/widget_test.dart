import 'package:flutter_test/flutter_test.dart';
import 'package:worship_loop/main.dart';

void main() {
  testWidgets('shows the Worship Loop mixer preview', (tester) async {
    await tester.pumpWidget(const WorshipLoopApp());

    expect(find.text('Worship Loop'), findsOneWidget);
    expect(find.text('TAP TEMPO'), findsOneWidget);
    expect(find.text('Pad 1'), findsOneWidget);
    expect(find.text('Percussion 1'), findsOneWidget);
    expect(find.text('SMOOTH TEMPO TRANSITION'), findsOneWidget);
  });
}
