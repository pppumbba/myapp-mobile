import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/liquid_switch.dart';

LiquidSwitchPainter painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.descendant(of: find.byType(LiquidSwitch), matching: find.byType(CustomPaint))).painter! as LiquidSwitchPainter;

void main() {
  test('the spring rises past 1 and settles within about 0.6s', () {
    expect(liquidSpring(0), 0);
    final peak = [for (var t = 0.0; t < 0.6; t += 0.01) liquidSpring(t)].reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.05));
    expect(liquidSpring(0.8), closeTo(1, 0.02));
  });

  testWidgets('tapping springs the knob over, the droplets trail it, and it settles on', (tester) async {
    var value = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(builder: (context, set) => LiquidSwitch(value: value, onChanged: (v) => set(() => value = v))),
        ),
      ),
    ));
    expect(painterOf(tester).p, 0);

    await tester.tap(find.byType(LiquidSwitch));
    expect(value, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = painterOf(tester);
    expect(mid.p, inExclusiveRange(0, 1));
    expect(mid.trail1, lessThan(mid.p), reason: 'droplets are behind the knob');
    expect(mid.trail2, lessThan(mid.trail1));
    expect(mid.speed, greaterThan(0));

    await tester.pumpAndSettle();
    expect(painterOf(tester).p, closeTo(1, 0.001));

    // Flipped back mid-motion it springs from where it is, not from the far end.
    await tester.tap(find.byType(LiquidSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final halfway = painterOf(tester).p;
    await tester.tap(find.byType(LiquidSwitch));
    await tester.pump();
    expect(painterOf(tester).p, closeTo(halfway, 0.05));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(painterOf(tester).p, closeTo(1, 0.001));
  });

  testWidgets('read-only does not toggle', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: LiquidSwitch(value: true, onChanged: null)))));
    await tester.tap(find.byType(LiquidSwitch));
    await tester.pumpAndSettle();
    expect(painterOf(tester).p, 1);
  });
}
