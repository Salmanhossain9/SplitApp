import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitbit/core/person.dart';
import 'package:splitbit/theme/app_theme.dart';
import 'package:splitbit/theme/tokens.dart';
import 'package:splitbit/ui/ui.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: Center(child: SizedBox(width: 342, child: child))),
    );

void main() {
  semanticsTests();
  testWidgets('AmountField reports integer poisha and refuses a third decimal', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(host(AmountField(poisha: 0, onChanged: values.add)));
    await tester.enterText(find.byType(TextField), '412.5');
    expect(values.last, 41250);
    await tester.enterText(find.byType(TextField), '412.567');
    // The formatter rejects the third decimal, so the previous text (and value) stays.
    expect(values.last, 41250);
    expect(find.text('412.5'), findsOneWidget);
  });

  testWidgets('AmountField follows outside changes (split the rest equally)', (tester) async {
    await tester.pumpWidget(host(AmountField(poisha: 1000, onChanged: (_) {})));
    expect(find.text('10'), findsOneWidget);
    await tester.pumpWidget(host(AmountField(poisha: 5050, onChanged: (_) {})));
    expect(find.text('50.5'), findsOneWidget);
  });

  testWidgets('ModeSwitch order is by items, equally, custom', (tester) async {
    await tester.pumpWidget(host(ModeSwitch(selected: ClaimMode.items, onChanged: (_) {})));
    final xs = ['by items', 'equally', 'custom'].map((t) => tester.getCenter(find.text(t)).dx).toList();
    expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
  });

  testWidgets('NameChip fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(NameChip(label: 'Rafi', on: false, onTap: () => taps++)));
    await tester.tap(find.text('Rafi'));
    expect(taps, 1);
  });

  testWidgets('GroupStack tap reports the group; front card moves to slot 0', (tester) async {
    const a = Person(id: 'a', name: 'You');
    const groups = [
      GroupCardData(id: 'g1', name: 'NSU boys', members: [a]),
      GroupCardData(id: 'g2', name: 'Roommates', members: [a]),
    ];
    String? tapped;
    var front = 'g1';
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, set) => GroupStack(
        groups: groups,
        frontId: front,
        onTap: (g) => set(() {
          tapped = g.id;
          front = g.id;
        }),
      ),
    )));
    final before = tester.getTopLeft(find.text('Roommates')).dy;
    await tester.tap(find.text('Roommates'));
    await tester.pumpAndSettle();
    expect(tapped, 'g2');
    expect(tester.getTopLeft(find.text('Roommates')).dy, lessThan(before));
  });
}

void semanticsTests() {
  testWidgets('tappable things are their own button for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(Row(children: [
      Text('good evening.', style: AppType.display36),
      NewBillPill(onTap: () {}),
    ])));
    // The label is just "new bill", not "good evening. new bill".
    expect(
      tester.getSemantics(find.text('new bill')),
      isSemantics(label: 'new bill', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
