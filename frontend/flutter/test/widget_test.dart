import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

void main() {
  testWidgets('Valley theme boots a release shell scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ValleyBrandTheme.dark(),
        home: const Scaffold(body: Center(child: Text('Valley release shell'))),
      ),
    );

    expect(find.text('Valley release shell'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
