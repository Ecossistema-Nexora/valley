import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valley_super_app/src/data/product_api_repository.dart';
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

  testWidgets('Valley product repository boots from bundled catalog', (
    WidgetTester tester,
  ) async {
    const ProductApiRepository repository = ProductApiRepository();
    final data = await repository.load();

    expect(data.modules.map((module) => module.id), contains('STOCK'));
    expect(data.items.length, greaterThanOrEqualTo(630));
    expect(
      data.items.where(
        (item) => item.ctaPath.contains('/api/actions/checkout'),
      ),
      isNotEmpty,
    );
  });
}
