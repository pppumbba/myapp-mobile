import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/inchworm_tabs.dart';

void main() {
  const a = (left: 10.0, right: 50.0), b = (left: 200.0, right: 260.0);

  test('moving right, the front (right) edge arrives first, then the back catches up', () {
    final mid = inchwormEdges(0.28, a, b);
    expect(mid.right, closeTo(260, 0.001));
    expect(mid.left, lessThan(200));
    final end = inchwormEdges(0.42, a, b);
    expect(end.left, closeTo(200, 0.001));
    expect(end.right, closeTo(260, 0.001));
  });

  test('moving left, the left edge leads', () {
    final mid = inchwormEdges(0.28, b, a);
    expect(mid.left, closeTo(10, 0.001));
    expect(mid.right, greaterThan(50));
  });

  test('at the tap nothing has moved', () {
    expect(inchwormEdges(0, a, b), a);
  });

  testWidgets('tapping a tab reports it and the pages slide to it', (tester) async {
    var index = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(children: [
            InchwormTabBar(labels: const ['Main', 'Costs'], index: index, onTap: (i) => setState(() => index = i)),
            Expanded(
              child: SpringPages(index: index, count: 2, builder: (_, i) => Center(child: Text('page $i'))),
            ),
          ]),
        ),
      ),
    ));
    expect(find.text('page 0'), findsOneWidget);
    expect(find.text('page 1'), findsNothing);

    await tester.tap(find.text('Costs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('page 0'), findsOneWidget, reason: 'both pages show while sliding');
    expect(find.text('page 1'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(index, 1);
    expect(find.text('page 0'), findsNothing);
    expect(find.text('page 1'), findsOneWidget);
  });
}
