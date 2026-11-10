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

  testWidgets('five tabs stay fixed: no scrolling, all in view', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PillNavBar(
          selectedIndex: 0,
          destinations: [for (var k = 0; k < 5; k++) PillDestination(icon: Icons.circle_outlined, label: 'Tab $k')],
          onDestinationSelected: (_) {},
        ),
      ),
    ));
    expect(find.descendant(of: find.byType(PillNavBar), matching: find.byType(Scrollable)), findsNothing);
    for (var k = 0; k < 5; k++) {
      expect(find.byTooltip('Tab $k'), findsOneWidget);
    }
  });

  group('six tabs or more: a scrolling strip', () {
    const names = ['Overview', 'Assets', 'Maintenance', 'Finance', 'Setup', 'Reports'];
    const icons = [Icons.bar_chart, Icons.inventory_2_outlined, Icons.build_outlined, Icons.receipt_long_outlined, Icons.settings_outlined, Icons.description_outlined];

    Future<ValueNotifier<int>> pumpBar(WidgetTester tester, {int start = 0}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selected = ValueNotifier(start);
      addTearDown(selected.dispose);
      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (_, i, _) => Scaffold(
            bottomNavigationBar: PillNavBar(
              selectedIndex: i,
              destinations: [for (var k = 0; k < names.length; k++) PillDestination(icon: icons[k], label: names[k])],
              onDestinationSelected: (k) => selected.value = k,
            ),
          ),
        ),
      ));
      return selected;
    }

    ScrollPosition strip(WidgetTester tester) =>
        tester.state<ScrollableState>(find.descendant(of: find.byType(PillNavBar), matching: find.byType(Scrollable))).position;

    testWidgets('it starts at the first tab and stops at the last; nothing repeats', (tester) async {
      await pumpBar(tester);
      expect(strip(tester).pixels, 0);
      for (final n in names.take(4)) {
        expect(find.byTooltip(n), findsOneWidget, reason: n);
      }
      await tester.drag(find.byType(ListView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(strip(tester).pixels, strip(tester).maxScrollExtent);
      expect(find.byTooltip('Reports'), findsOneWidget);
      expect(find.byTooltip('Overview'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(strip(tester).pixels, 0);
    });

    testWidgets('opened on a later tab, that tab is in view', (tester) async {
      await pumpBar(tester, start: 5);
      final bar = tester.getRect(find.byType(ListView));
      expect(bar.contains(tester.getCenter(find.byTooltip('Reports'))), isTrue);
    });

    testWidgets('a tab picked while scrolled off comes back into view', (tester) async {
      final selected = await pumpBar(tester);
      await tester.drag(find.byType(ListView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Overview'), findsNothing);
      await tester.tap(find.byTooltip('Reports'));
      await tester.pumpAndSettle();
      expect(selected.value, 5);
      selected.value = 0; // system back, the menu search
      await tester.pumpAndSettle();
      expect(strip(tester).pixels, 0);
      expect(tester.getSemantics(find.bySemanticsLabel('Overview')).flagsCollection.isSelected, Tristate.isTrue);
    });
  });
}
