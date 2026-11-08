import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/pull_refresh.dart';

void main() {
  Widget list(Future<void> Function() onRefresh) => MaterialApp(
        home: Scaffold(
          body: PullRefresh(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('Row $i'))],
            ),
          ),
        ),
      );

  test('the list follows the pull, then resists', () {
    expect(pullOffset(0), 0);
    expect(pullOffset(40), greaterThan(20));
    expect(pullOffset(2000), lessThan(121));
  });

  testWidgets('a long pull refreshes, the list moves down meanwhile, then settles back', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(list(() {
      calls++;
      return done.future;
    }));
    final top = tester.getTopLeft(find.text('Row 0')).dy;

    await tester.drag(find.text('Row 0'), const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(tester.getTopLeft(find.text('Row 0')).dy, greaterThan(top + 40), reason: 'held open while refreshing');

    done.complete();
    // The check holds a moment before the gap closes.
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Row 0')).dy, closeTo(top, 0.5));
  });

  testWidgets('a short pull springs back without refreshing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(list(() async => calls++));
    final top = tester.getTopLeft(find.text('Row 0')).dy;
    await tester.drag(find.text('Row 0'), const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getTopLeft(find.text('Row 0')).dy, closeTo(top, 0.5));
  });

  testWidgets('a pull further down the list just scrolls', (tester) async {
    var calls = 0;
    await tester.pumpWidget(list(() async => calls++));
    await tester.drag(find.text('Row 3'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Row 12'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
