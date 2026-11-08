import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/grid/swipe_actions.dart';

void main() {
  late List<String> pressed;
  late int removed;
  late bool deleteSucceeds;

  Future<void> pump(WidgetTester tester) async {
    pressed = [];
    removed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: SwipeActions(
              actions: [
                SwipeAction(icon: Icons.edit, label: 'Edit', color: Colors.indigo, onPressed: () async {
                  pressed.add('edit');
                  return false;
                }),
                SwipeAction(icon: Icons.delete, label: 'Delete', color: deleteRed, destructive: true, onPressed: () async {
                  pressed.add('delete');
                  return deleteSucceeds;
                }),
              ],
              onRemoved: () => removed++,
              child: const SizedBox(height: 80, child: Card(child: Center(child: Text('Boardroom table')))),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('a short swipe opens the buttons; tapping one runs it and closes the card', (tester) async {
    deleteSucceeds = false;
    await pump(tester);
    expect(find.text('Edit'), findsNothing);

    await tester.drag(find.text('Boardroom table'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(pressed, ['edit']);
    expect(find.text('Edit'), findsNothing, reason: 'closed again');
  });

  testWidgets('a long swipe deletes; the card is removed after flying off', (tester) async {
    deleteSucceeds = true;
    await pump(tester);
    await tester.drag(find.text('Boardroom table'), const Offset(-320, 0));
    await tester.pump();
    expect(pressed, ['delete']);
    expect(removed, 0, reason: 'not before the card has gone');
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('a cancelled delete brings the card back', (tester) async {
    deleteSucceeds = false;
    await pump(tester);
    await tester.drag(find.text('Boardroom table'), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(pressed, ['delete']);
    expect(removed, 0);
    expect(find.text('Delete'), findsNothing);
    expect(tester.getCenter(find.text('Boardroom table')).dx, closeTo(400, 1));
  });

  testWidgets('while open, tapping the card closes it instead of opening the record', (tester) async {
    deleteSucceeds = false;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeActions(
          actions: [SwipeAction(icon: Icons.edit, label: 'Edit', color: Colors.indigo, onPressed: () async => false)],
          child: ListTile(title: const Text('Row'), onTap: () => opened++),
        ),
      ),
    ));
    await tester.drag(find.text('Row'), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Row'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Row'));
    expect(opened, 1);
  });
}
