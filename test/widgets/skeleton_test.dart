import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/skeleton.dart';

void main() {
  final shapes = <String, Widget>{
    'cards': const CardListSkeleton(),
    'form': const FormSkeleton(),
    'workspace': const WorkspaceSkeleton(),
    'rows': const Shimmer(child: RowGroupSkeleton()),
    'chart': const ChartSkeleton(),
  };

  for (final brightness in Brightness.values) {
    for (final MapEntry(:key, :value) in shapes.entries) {
      testWidgets('$key skeleton lays out on a small phone (${brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: value),
        ));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        expect(find.byType(SkeletonBox), findsWidgets);
      });
    }
  }

  testWidgets('cards skeleton sits inside a scroll view (grid pull to refresh)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: CardListSkeleton())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonCard), findsNWidgets(6));
  });
}
