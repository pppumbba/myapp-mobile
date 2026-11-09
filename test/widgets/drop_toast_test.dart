import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/nav/notifications.dart';
import 'package:wand_mobile/widgets/drop_toast.dart';

AppNotification n(int id, {bool read = false}) => AppNotification(id: id, title: 'N$id', read: read);

void main() {
  test('only a newer unread notification counts as arrived, never the first read', () {
    final before = NotificationPage([n(5), n(4, read: true)], 1);
    expect(arrivedNotification(null, before), isNull, reason: 'first read after sign-in');
    expect(arrivedNotification(before, before), isNull);
    expect(arrivedNotification(before, NotificationPage([n(7), n(6), n(5)], 3))?.id, 7, reason: 'the newest of the new');
    expect(arrivedNotification(before, NotificationPage([n(6, read: true), n(5)], 1)), isNull, reason: 'already read elsewhere');
  });

  test('the drop falls, opens with a little overshoot, holds, and is pulled back up', () {
    expect(DropPose.at(0).fall, 0);
    expect(DropPose.at(0.36).fall, 1);
    final peak = [for (var a = 0.4; a < 1.2; a += 0.02) DropPose.at(a).open].reduce((x, y) => x > y ? x : y);
    expect(peak, greaterThan(1), reason: 'springs past full width');
    expect(DropPose.at(2.5, hold: 4.5).content, 1);
    expect(DropPose.at(2.5, hold: 4.5).open, closeTo(1, 0.01));
    final end = DropPose.total(hold: 4.5);
    expect(DropPose.at(end, hold: 4.5).fall, 0, reason: 'back inside the top edge');
    expect(DropPose.at(end, hold: 4.5).open, 0);
  });

  testWidgets('shows the message, a tap opens it and the toast leaves', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDropToast(context, title: 'Mika', body: 'See you at 7?', time: 'now', onTap: () => tapped++),
            child: const Text('Go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('See you at 7?'), findsOneWidget);
    expect(find.text('now'), findsOneWidget);

    await tester.tap(find.text('Mika'));
    expect(tapped, 1);
    await tester.pumpAndSettle();
    expect(find.text('Mika'), findsNothing, reason: 'pulled back up and removed');
  });
}
