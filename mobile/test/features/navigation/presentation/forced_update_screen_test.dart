import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/navigation/presentation/forced_update_screen.dart';

void main() {
  testWidgets('ForcedUpdateScreen renders blocking UI and version data', (WidgetTester tester) async {
    const testStoreUrl = 'https://play.google.com/store/apps/details?id=com.reparatutti.app';
    const testMessage = 'Actualización requerida para garantizar la seguridad.';

    await tester.pumpWidget(
      const MaterialApp(
        home: ForcedUpdateScreen(
          storeUrl: testStoreUrl,
          message: testMessage,
          minBuild: 10,
          currentBuild: 3,
        ),
      ),
    );

    // Verify blocking PopScope with canPop false
    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
    expect(popScopeWidget.canPop, isFalse);

    // Verify texts
    expect(find.text('Actualización Requerida'), findsOneWidget);
    expect(find.text('Nueva Versión de Reparatutti'), findsOneWidget);
    expect(find.text(testMessage), findsOneWidget);
    expect(find.text('Build 3'), findsOneWidget);
    expect(find.text('Build 10'), findsOneWidget);
    expect(find.text('Actualizar en la Tienda'), findsOneWidget);
  });
}
