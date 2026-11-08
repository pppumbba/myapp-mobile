import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/expanding_search.dart';

void main() {
  late List<String> sent;
  late TextEditingController text;

  Future<void> pump(WidgetTester tester, {String initial = ''}) async {
    sent = [];
    text = TextEditingController(text: initial);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SizedBox(width: 360, child: ExpandingSearch(controller: text, onChanged: sent.add, hint: 'Search')),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
  }

  test('easeBack starts at 0, overshoots, ends at 1', () {
    expect(easeBack(0), closeTo(0, 1e-9));
    expect(easeBack(0.56), greaterThan(1.1));
    expect(easeBack(1), 1);
  });

  testWidgets('rests as a round button; a tap stretches it into a focused bar', (tester) async {
    await pump(tester);
    expect(find.byType(TextField), findsNothing);
    expect(tester.getSize(find.byTooltip('Search')).width, closeTo(48, 1));

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, true);

    await tester.enterText(find.byType(TextField), 'pump');
    expect(sent, ['pump']);
  });

  testWidgets('× clears the text first, then folds the bar back', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pump');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(text.text, '');
    expect(sent.last, '');
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('with a search already typed it starts open', (tester) async {
    await pump(tester, initial: 'lathe');
    expect(find.widgetWithText(TextField, 'lathe'), findsOneWidget);
  });
}
