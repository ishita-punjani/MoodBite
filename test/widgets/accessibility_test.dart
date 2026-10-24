import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/widgets/emoji.dart';
import 'package:moodbite/widgets/quantity_stepper.dart';
import 'package:moodbite/widgets/state_views.dart';

Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('quantity stepper buttons are at least 48dp and the count is announced', (tester) async {
    final semantics = tester.ensureSemantics();
    var quantity = 2;
    await tester.pumpWidget(host(QuantityStepper(
      quantity: quantity,
      onIncrement: () => quantity++,
      onDecrement: () => quantity--,
    )));
    for (final tooltip in ['Remove one', 'Add one']) {
      final size = tester.getSize(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)).first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel('Quantity 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Add one'));
    expect(quantity, 3);
    semantics.dispose();
  });

  testWidgets('a labelled emoji is announced by its label, a decorative one is not announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const Column(
      mainAxisSize: MainAxisSize.min,
      children: [Emoji('🎉', label: 'Celebration'), Emoji('🍛')],
    )));
    expect(find.bySemanticsLabel('Celebration'), findsOneWidget);
    expect(find.bySemanticsLabel('🍛'), findsNothing);
    expect(find.bySemanticsLabel('🎉'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the empty state reads its title, not the emoji', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const EmptyView(emoji: '🛍️', title: 'Your cart is empty')));
    expect(find.bySemanticsLabel('Your cart is empty'), findsOneWidget);
    expect(find.bySemanticsLabel('🛍️'), findsNothing);
    semantics.dispose();
  });
}
