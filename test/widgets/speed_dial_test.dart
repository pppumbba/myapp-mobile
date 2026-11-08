import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/speed_dial.dart';

void main() {
  late List<String> ran;

  Future<void> pump(WidgetTester tester, {List<String> items = const ['New work order', 'Import meter readings'], VoidCallback? onPressed}) async {
    ran = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: SpeedDialFab(
          tooltip: 'Add',
          onPressed: onPressed,
          items: [
            for (final s in items) SpeedDialItem(icon: Icons.add, label: s, color: Colors.teal, onTap: () => ran.add(s)),
          ],
        ),
      ),
    ));
  }

  testWidgets('with one way to add, a tap just runs it', (tester) async {
    var pressed = 0;
    await pump(tester, items: const [], onPressed: () => pressed++);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });

  testWidgets('a tap opens the options with labels; picking one closes the dial and runs it', (tester) async {
    await pump(tester);
    expect(find.text('New work order'), findsNothing);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New work order'), findsOneWidget);
    expect(find.text('Import meter readings'), findsOneWidget);

    await tester.tap(find.text('Import meter readings'));
    await tester.pumpAndSettle();
    expect(ran, ['Import meter readings']);
    expect(find.text('New work order'), findsNothing);
  });

  testWidgets('the options stack upward from the button, the first one lowest', (tester) async {
    await pump(tester);
    final fab = tester.getCenter(find.byTooltip('Add'));
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    final first = tester.getCenter(find.text('New work order')).dy, second = tester.getCenter(find.text('Import meter readings')).dy;
    expect(first, lessThan(fab.dy));
    expect(second, lessThan(first));
  });

  testWidgets('tapping the dim or pressing Back closes without running anything', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('New work order'), findsNothing);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('New work order'), findsNothing);
    expect(ran, isEmpty);
  });
}
