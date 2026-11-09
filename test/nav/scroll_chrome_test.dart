import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/nav/scroll_chrome.dart';

void main() {
  Future<void> pump(WidgetTester tester, {int rows = 60, Object? resetKey}) => tester.pumpWidget(MaterialApp(
        home: ScrollChrome(
          resetKey: resetKey,
          builder: (context, shown) => Scaffold(
            body: Column(children: [
              CollapseOnScroll(shown: shown, child: const SizedBox(height: 56, child: Text('Top bar'))),
              Expanded(
                child: Builder(
                  builder: (context) => Column(children: [
                    // A header further down reads the same flag from the scope, like a grid's search row.
                    CollapseOnScroll(shown: ScrollChrome.maybeOf(context), child: const SizedBox(height: 48, child: Text('Filters'))),
                    Expanded(
                      child: ListView(children: [for (var i = 0; i < rows; i++) SizedBox(height: 60, child: Text('Row $i'))]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ));

  double heightOf(WidgetTester tester, String text) =>
      tester.getSize(find.ancestor(of: find.text(text), matching: find.byType(ClipRect)).first).height;

  testWidgets('scrolling down folds the bars away, scrolling up brings them back', (tester) async {
    await pump(tester);
    expect(heightOf(tester, 'Top bar'), 56);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'Top bar'), 0);
    expect(heightOf(tester, 'Filters'), 0);

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'Top bar'), 56);
    expect(heightOf(tester, 'Filters'), 48);
  });

  testWidgets('a short list never hides them, and another screen shows them again', (tester) async {
    await pump(tester, rows: 8);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'Top bar'), 56, reason: 'too little to scroll for');

    await pump(tester, resetKey: 'a');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'Top bar'), 0);
    await pump(tester, resetKey: 'b');
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'Top bar'), 56);
  });
}
