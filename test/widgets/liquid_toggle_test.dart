import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/liquid_toggle.dart';

const _options = [
  LiquidOption<String?>(null, Icons.brightness_auto_outlined, 'System'),
  LiquidOption<String?>('light', Icons.light_mode_outlined, 'Light'),
  LiquidOption<String?>('dark', Icons.dark_mode_outlined, 'Dark'),
];

void _expectPicked(WidgetTester tester, String picked, String other) {
  expect(tester.getSemantics(find.bySemanticsLabel(picked)), isSemantics(isSelected: true));
  expect(tester.getSemantics(find.bySemanticsLabel(other)), isSemantics(isSelected: false));
}

void main() {
  Future<List<String?>> pump(WidgetTester tester, {bool fail = false}) async {
    final saved = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidToggle<String?>(
            value: null,
            options: _options,
            onChanged: (v) async {
              saved.add(v);
              if (fail) throw Exception('offline');
            },
          ),
        ),
      ),
    ));
    return saved;
  }

  testWidgets('a pick moves the drop at once and saves it', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.byTooltip('Dark'));
    await tester.pumpAndSettle();
    expect(saved, ['dark']);
    _expectPicked(tester, 'Dark', 'System');
  });

  testWidgets('a pick that fails to save flows back', (tester) async {
    final saved = await pump(tester, fail: true);
    await tester.tap(find.byTooltip('Light'));
    await tester.pumpAndSettle();
    expect(saved, ['light']);
    _expectPicked(tester, 'System', 'Light');
  });
}
