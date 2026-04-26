import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ej_flutter/views/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton renders text and handles taps', (
    WidgetTester tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            text: 'Continue',
            onPressed: () {
              tapCount++;
            },
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('PrimaryButton shows a loading indicator when busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PrimaryButton(text: 'Saving', isLoading: true)),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Saving'), findsNothing);
  });
}
