import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/nav/pill_bar.dart';

void main() {
  test('at rest the pill is 86 px wide on a 102.5 px tab', () {
    for (var i = 0; i < 4; i++) {
      final e = pillEdges(t: 2, from: 0, to: i, count: 4, width: 410);
      expect(e.right - e.left, closeTo(86, 0.01));
      expect((e.left + e.right) / 2, closeTo(102.5 * (i + 0.5), 0.01));
    }
  });

  test('moving right, the leading (right) edge runs ahead and the pill stretches', () {
    final e = pillEdges(t: 0.08, from: 0, to: 3, count: 4, width: 410);
    final rest = pillEdges(t: 0, from: 0, to: 3, count: 4, width: 410);
    expect(e.right - rest.right, greaterThan(e.left - rest.left));
    expect(e.right - e.left, greaterThan(86));
  });

  test('moving left, the left edge leads', () {
    final e = pillEdges(t: 0.08, from: 3, to: 0, count: 4, width: 410);
    final rest = pillEdges(t: 0, from: 3, to: 0, count: 4, width: 410);
    expect(rest.left - e.left, greaterThan(rest.right - e.right));
  });

  test('an overshooting edge flattens 6 px inside the bar', () {
    for (var t = 0.0; t < 1.2; t += 0.01) {
      final e = pillEdges(t: t, from: 0, to: 3, count: 4, width: 410);
      expect(e.right, lessThanOrEqualTo(404));
      expect(e.left, greaterThanOrEqualTo(6));
    }
  });

  test('spring starts at 0 and settles at 1', () {
    expect(springAt(0, 19, 0.55), 0);
    expect(springAt(1.0, 11, 0.72), closeTo(1, 0.001));
  });

  testWidgets('tapping a tab reports it; the selected tab is marked for screen readers', (tester) async {
    var picked = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PillNavBar(
          selectedIndex: 0,
          destinations: const [
            PillDestination(icon: Icons.home_outlined, label: 'Assets'),
            PillDestination(icon: Icons.build_outlined, label: 'Work orders'),
          ],
          onDestinationSelected: (i) => picked = i,
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Work orders'));
    expect(find.text('Work orders'), findsNothing, reason: 'icons only, no names under them');
    expect(picked, 1);
    expect(tester.getSemantics(find.bySemanticsLabel('Assets')).flagsCollection.isSelected, Tristate.isTrue);
  });
}
