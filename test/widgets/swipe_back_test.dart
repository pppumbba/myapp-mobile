import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/swipe_back.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: SwipeBackTransitionsBuilder()}),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('Lisbon'))))),
              child: const Text('Trips'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
  }

  double glow(WidgetTester tester) => tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)).last.opacity;

  testWidgets('a page slides in and is dragged back from its left edge, with the glow lit while held', (tester) async {
    await open(tester);
    expect(find.text('Lisbon'), findsOneWidget);
    expect(glow(tester), 0);

    final g = await tester.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(400, 0));
    await tester.pump();
    expect(glow(tester), 1, reason: 'edge glows while dragging');
    expect(tester.getTopLeft(find.text('Lisbon')).dx, greaterThan(600), reason: 'page follows the finger');
    expect(find.text('Trips'), findsOneWidget, reason: 'the list shows underneath');

    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Lisbon'), findsNothing, reason: 'let go past halfway: the page flies off');
  });

  testWidgets('a short drag springs the page back', (tester) async {
    await open(tester);
    final g = await tester.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Lisbon'), findsOneWidget);
    expect(glow(tester), 0);
  });

  testWidgets('the Android system back swipe drags the page the same way', (tester) async {
    await open(tester);
    Future<void> send(String method, [Map<String, dynamic>? args]) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );

    await send('startBackGesture', {'touchOffset': [5.0, 300.0], 'progress': 0.0, 'swipeEdge': 0});
    await send('updateBackGestureProgress', {'x': 300.0, 'y': 300.0, 'progress': 0.5, 'swipeEdge': 0});
    await tester.pump();
    expect(tester.getTopLeft(find.text('Lisbon')).dx, greaterThan(300), reason: 'page follows the system swipe');
    expect(glow(tester), 1);

    await send('commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('Lisbon'), findsNothing);
  });
}
