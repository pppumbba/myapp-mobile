import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/snap_sheet.dart';

void main() {
  Future<Future<String?>> open(WidgetTester tester, {SnapHeight initial = SnapHeight.half}) async {
    late Future<String?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => result = showSnapSheet<String>(
                context,
                initial: initial,
                builder: (ctx) => Center(child: TextButton(onPressed: () => Navigator.pop(ctx, 'picked'), child: const Text('Pick'))),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  // The sheet's top edge: where its handle sits, minus the handle's half height.
  double top(WidgetTester tester) => tester.getTopLeft(find.bySemanticsLabel('Drag handle')).dy;

  testWidgets('opens at the given height and returns what the content pops', (tester) async {
    final result = await open(tester);
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(top(tester), closeTo(screen - (screen - 8) * 0.64, 2), reason: 'Half is 64% of the room');
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(await result, 'picked');
  });

  testWidgets('dragged up by the handle and let go part-way, it springs into Full', (tester) async {
    await open(tester);
    final half = top(tester);
    await tester.drag(find.bySemanticsLabel('Drag handle'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(top(tester), lessThan(half - 150), reason: 'went on past where the finger let go');
    expect(top(tester), closeTo(8, 2), reason: 'Full reaches 8px under the status bar');
  });

  testWidgets('a short drag springs back to the height it came from', (tester) async {
    await open(tester);
    final half = top(tester);
    await tester.drag(find.bySemanticsLabel('Drag handle'), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(top(tester), closeTo(half, 1));
  });

  testWidgets('flung down from Peek, or a tap on the dim, closes it', (tester) async {
    var result = await open(tester, initial: SnapHeight.peek);
    await tester.fling(find.bySemanticsLabel('Drag handle'), const Offset(0, 200), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Pick'), findsNothing);
    expect(await result, isNull);

    result = await open(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Pick'), findsNothing);
    expect(await result, isNull);
  });
}
