import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/glow_border.dart';

void main() {
  test('the glow fades in between the plain and the focused outline', () {
    const plain = GlowOutlineBorder(), focused = GlowOutlineBorder(glow: 1);
    final mid = ShapeBorder.lerp(plain, focused, 0.5);
    expect(mid, isA<GlowOutlineBorder>());
    expect((mid! as GlowOutlineBorder).glow, 0.5);
    expect(plain.copyWith(glow: 1), focused);
  });

  testWidgets('a focused field paints the glowing outline, with the label floated', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextField(
            focusNode: focus,
            decoration: withGlowBorders(const InputDecoration(labelText: 'Email', helperText: "We'll never share it."), Theme.of(context).colorScheme),
          ),
        ),
      ),
    ));
    final restY = tester.getCenter(find.text('Email')).dy;

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Email')).dy, lessThan(restY), reason: 'label floats up into the outline');
    expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.focusedBorder is GlowOutlineBorder), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mia@mail.com');
    expect(find.text('mia@mail.com'), findsOneWidget);
  });
}
