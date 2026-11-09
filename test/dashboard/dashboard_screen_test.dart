import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/dashboard/dashboard_screen.dart';
import 'package:wand_mobile/meta/defs.dart';

void main() {
  final charts = <int, Map<String, dynamic>>{
    1: {'type': 'kpi', 'format': 'money', 'kpi': {'value': 1234567, 'previous': null}},
    2: {'type': 'kpi', 'kpi': {'value': 15, 'previous': 10}},
    3: {
      'type': 'donut',
      'series': [{'key': 'm0', 'label': 'Assets'}],
      'rows': [
        {'x': 'in service', 'label': 'in service', 'values': {'m0': 12}},
        {'x': 'disposed', 'label': 'disposed', 'values': {'m0': 3}},
      ],
    },
    4: {
      'type': 'bar',
      'series': [{'key': 'm0', 'label': 'Assets'}],
      'rows': [{'x': '1', 'label': 'Power', 'values': {'m0': 7}}],
    },
    5: {
      'type': 'column',
      'format': 'money',
      'series': [{'key': 'm0', 'label': 'Labor'}, {'key': 'm1', 'label': 'Parts'}],
      'rows': [{'x': '2026-10', 'label': '2026-10', 'values': {'m0': 100, 'm1': 50}}],
    },
    6: {
      'type': 'table',
      'series': [{'key': 'm0', 'label': 'Spend'}, {'key': 'm1', 'label': 'Work orders'}],
      'rows': [{'x': '9', 'label': 'Forklift', 'values': {'m0': 320.5, 'm1': 2}}],
    },
  };

  testWidgets('a dashboard draws each chart by its type, number tiles two to a row', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        for (final e in charts.entries) ...[
          chartProvider(e.key).overrideWith((ref) async => ChartData.fromJson(e.value)),
          metaDefProvider(e.key).overrideWith((ref) async => MetaDef(Meta(id: e.key, name: 'Chart ${e.key}', type: 'chart'), const [])),
        ],
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            meta: Meta(id: 100, name: 'Overview', type: 'dashboard'),
            params: [for (final id in charts.keys) MetaParam(id: id, paramName: 'c$id', refMetaId: id, orderNumber: id)],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1.23M'), findsOneWidget, reason: 'large money shortened');
    expect(find.text('▲ 50.0%'), findsOneWidget, reason: 'change against the previous period');
    expect(tester.getTopLeft(find.text('Chart 1')).dy, tester.getTopLeft(find.text('Chart 2')).dy, reason: 'tiles share a row');
    expect(find.text('in service'), findsOneWidget);
    expect(find.text('15'), findsWidgets, reason: 'the donut total');
    expect(find.text('Power'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Forklift'), 200);
    expect(find.text('Oct'), findsOneWidget, reason: 'month buckets by name');
    expect(find.text('Labor'), findsOneWidget, reason: 'two series get a legend');
    expect(find.text('320.50'), findsOneWidget);
  });
}
