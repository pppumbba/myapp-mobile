import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/confirm_dialog.dart';

void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    late Future<bool> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => result = showConfirmDialog(
                context,
                title: 'Delete file?',
                message: 'It will be removed for good.',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                destructive: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    return result;
  }

  double scaleOf(WidgetTester tester) =>
      tester.widget<Transform>(find.byKey(const ValueKey('confirm-card'))).transform.entry(0, 0);

  testWidgets('pops in from 72% past full size and settles; Delete answers true', (tester) async {
    final result = await open(tester);
    await tester.pump();
    expect(scaleOf(tester), closeTo(0.72, 0.01));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaleOf(tester), greaterThan(1), reason: 'overshoots');
    await tester.pumpAndSettle();
    expect(scaleOf(tester), closeTo(1, 0.001));
    expect(find.text('It will be removed for good.'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester), lessThan(1), reason: 'shrinks on the way out');
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('Cancel, or a tap outside, answers false', (tester) async {
    var result = await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    result = await open(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsNothing);
    expect(await result, isFalse);
  });
}
