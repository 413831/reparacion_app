import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Reparatutti app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ReparatuttiApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title is rendered
    expect(find.text('Reparatutti'), findsOneWidget);
  });
}
