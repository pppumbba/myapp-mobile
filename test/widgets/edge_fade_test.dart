import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/edge_fade.dart';

void main() {
  Future<void> pumpList(WidgetTester tester, {bool animationsOff = false}) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(400, 600), disableAnimations: animationsOff),
        child: Scaffold(
          body: ListView.builder(
            itemCount: 30,
            itemExtent: 100,
            itemBuilder: (_, i) => EdgeFade(endInset: 50, child: Container(key: ValueKey(i), color: Colors.indigo, child: Text('Item $i'))),
          ),
        ),
      ),
    ));
  }

  /// The alpha an item paints at: 255 when drawn as is.
  int alphaOf(WidgetTester tester, int i) {
    final r = tester.renderObject(find.ancestor(of: find.byKey(ValueKey(i)), matching: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_EdgeFade')));
    final layer = r.debugLayer;
    return layer is OpacityLayer ? layer.alpha ?? 255 : 255;
  }

  testWidgets('items wholly in view paint as they are; at the top of the list nothing shrinks', (tester) async {
    await pumpList(tester);
    for (final i in [0, 1, 2, 3, 4]) {
      expect(alphaOf(tester, i), 255, reason: 'item $i');
    }
    // Item 5 (500–600) runs under the 50 px bar: half of it shows, so it is half faded in.
    expect(alphaOf(tester, 5), inExclusiveRange(0, 255));
  });

  testWidgets('an item half scrolled past the top fades, and gone it is not painted', (tester) async {
    await pumpList(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
    // Item 1 now spans -50..50: half out at the top.
    expect(alphaOf(tester, 1), inExclusiveRange(0, 255));
    expect(alphaOf(tester, 2), 255);
  });

  testWidgets('with animations off nothing fades', (tester) async {
    await pumpList(tester, animationsOff: true);
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => '${w.runtimeType}' == '_EdgeFade'), findsNothing);
  });
}
