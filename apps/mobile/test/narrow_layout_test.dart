import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/ui.dart';

/// Phones are 360 to 412 dp wide and many people set a larger system font. A long price or title
/// must shrink to fit, never overflow.
Widget phone(Widget child, {required double width, double textScale = 1}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (c, app) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(width: width - 48, child: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  for (final (width, scale) in [(411.0, 1.0), (411.0, 1.3), (360.0, 1.15), (320.0, 1.3)]) {
    testWidgets('item card fits $width dp wide at font scale $scale', (tester) async {
      await tester.pumpWidget(phone(
        ItemEditCard(
          name: 'Caramel Banana French Toast',
          qty: 2,
          unitPrice: 59900,
          onName: (_) {},
          onQty: (_) {},
          onUnitPrice: (_) {},
          onDelete: () {},
        ),
        width: width,
        textScale: scale,
      ));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('top bar with a step pill keeps the title clear of the pill', (tester) async {
    await tester.pumpWidget(phone(
      const AppTopBar(title: 'add items', trailing: StepPill('step 2 of 3')),
      width: 411,
      textScale: 1.3,
    ));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('add items'));
    final pill = tester.getRect(find.text('step 2 of 3'));
    expect(title.right, lessThanOrEqualTo(pill.left));
  });
}
