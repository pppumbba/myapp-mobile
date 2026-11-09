import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart' show apiClientProvider;
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import '../widgets/pull_refresh.dart';

/// Series colours, in order: violet, cyan, pink, gold, mint, lilac.
const chartColors = [pillViolet, pillCyan, Color(0xFFFF5CA8), Color(0xFFFFD166), Color(0xFF3DDBB0), Color(0xFFB6A8FF)];

/// What `GET /metas/{id}/chart` answers.
class ChartData {
  final String type;
  final String? format;
  final List<({String key, String label})> series;
  final List<({String x, String label, Map<String, double> values})> rows;
  final double? kpi;
  final double? previous;
  ChartData({required this.type, this.format, this.series = const [], this.rows = const [], this.kpi, this.previous});

  static double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  factory ChartData.fromJson(Map<String, dynamic> j) {
    final kpi = j['kpi'] is Map ? j['kpi'] as Map : null;
    return ChartData(
      type: '${j['type'] ?? 'bar'}',
      format: j['format'] as String?,
      series: [
        for (final s in (j['series'] as List? ?? const []))
          if (s is Map) (key: '${s['key']}', label: '${s['label'] ?? s['key']}'),
      ],
      rows: [
        for (final r in (j['rows'] as List? ?? const []))
          if (r is Map)
            (
              x: r['x'] == null ? '' : '${r['x']}',
              // A group without a value (e.g. no date yet) is shown as a dash.
              label: '${r['label'] ?? r['x'] ?? '—'}',
              values: {
                if (r['values'] is Map)
                  for (final e in (r['values'] as Map).entries) '${e.key}': _num(e.value) ?? 0,
              },
            ),
      ],
      kpi: _num(kpi?['value']),
      previous: _num(kpi?['previous']),
    );
  }
}

final chartProvider = FutureProvider.family<ChartData, int>(retry: noRetry, (ref, id) async {
  final r = await ref.read(apiClientProvider).get<dynamic>('/metas/$id/chart');
  return ChartData.fromJson(Map<String, dynamic>.from(r as Map));
});

/// A dashboard meta: its charts top to bottom; number tiles two to a row.
class DashboardScreen extends ConsumerWidget {
  final Meta meta;
  final List<MetaParam> params;
  const DashboardScreen({super.key, required this.meta, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = [
      for (final p in [...params]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber)))
        if (p.refMetaId != null) p.refMetaId!,
    ];
    final kinds = {for (final id in charts) id: ref.watch(chartProvider(id)).value?.type};
    // Runs of number tiles share a two-column grid; everything else takes the full width.
    final blocks = <Widget>[];
    var tiles = <int>[];
    void flush() {
      for (var i = 0; i < tiles.length; i += 2) {
        blocks.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ChartCard(chartId: tiles[i])),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < tiles.length ? ChartCard(chartId: tiles[i + 1]) : const SizedBox.shrink()),
          ]),
        ));
      }
      tiles = [];
    }

    for (final id in charts) {
      if (kinds[id] == 'kpi') {
        tiles.add(id);
      } else {
        flush();
        blocks.add(ChartCard(chartId: id));
      }
    }
    flush();
    return PullRefresh(
      onRefresh: () async {
        for (final id in charts) {
          ref.invalidate(chartProvider(id));
        }
        await Future.wait([for (final id in charts) ref.read(chartProvider(id).future).catchError((_) => ChartData(type: ''))]);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
        itemCount: blocks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => blocks[i],
      ),
    );
  }
}

/// One chart meta in a card: its name, then the chart drawn by its type.
class ChartCard extends ConsumerWidget {
  final int chartId;
  const ChartCard({super.key, required this.chartId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(metaDefProvider(chartId)).value?.meta.name ?? '';
    final data = ref.watch(chartProvider(chartId));
    final kpi = data.value?.type == 'kpi';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: kpi ? 2 : 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          switch (data) {
            AsyncValue(:final value?) => _chart(value),
            AsyncValue(:final error?) => Row(children: [
                Expanded(
                  child: Text(error is ApiError ? error.message : AppLocalizations.of(context).somethingWrong,
                      style: theme.textTheme.bodySmall),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).retry,
                  onPressed: () => ref.invalidate(chartProvider(chartId)),
                  icon: const Icon(Icons.refresh),
                ),
              ]),
            _ => const SizedBox(height: 36, child: Center(child: RefreshRing(size: 28))),
          },
        ]),
      ),
    );
  }

  Widget _chart(ChartData d) => switch (d.type) {
        'kpi' => _Kpi(d),
        'donut' || 'pie' => _Donut(d),
        'column' || 'line' || 'area' => _Columns(d),
        'table' => _Table(d),
        _ => _Bars(d),
      };
}

/// Grouped digits; large numbers shortened (1.2M); money without decimals.
String chartNumber(double v, String? format, {bool short = false}) {
  if (short && v.abs() >= 100000) return NumberFormat.compact(locale: 'en_US').format(v);
  final whole = format == 'money' || v == v.roundToDouble();
  return NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: whole ? 0 : 2).format(v);
}

class _Kpi extends StatelessWidget {
  final ChartData d;
  const _Kpi(this.d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = d.kpi ?? 0, p = d.previous;
    final change = p == null || p == 0 ? null : (v - p) / p.abs() * 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(chartNumber(v, d.format, short: true),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
      ),
      if (change != null) ...[
        const SizedBox(height: 4),
        Text('${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: change >= 0 ? const Color(0xFF3DDBB0) : const Color(0xFFFF5CA8))),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  final List<(String, Color)> items;
  const _Legend(this.items);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(spacing: 14, runSpacing: 6, children: [
      for (final (label, color) in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: style),
        ]),
    ]);
  }
}

String _empty(BuildContext context) => AppLocalizations.of(context).noData;

/// Horizontal bars: one row per group, label above its bar, value at the end.
class _Bars extends StatelessWidget {
  final ChartData d;
  const _Bars(this.d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (d.rows.isEmpty || d.series.isEmpty) return Text(_empty(context));
    final key = d.series.first.key;
    final max = d.rows.map((r) => r.values[key] ?? 0).fold<double>(0, math.max);
    return Column(children: [
      for (final (i, r) in d.rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium)),
              Text(chartNumber(r.values[key] ?? 0, d.format),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 5),
            LayoutBuilder(builder: (_, box) {
              final share = max <= 0 ? 0.0 : ((r.values[key] ?? 0) / max).clamp(0.0, 1.0);
              return Stack(children: [
                Container(height: 8, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share),
                  duration: Duration(milliseconds: 500 + 60 * i),
                  curve: Curves.easeOutCubic,
                  builder: (_, k, _) => Container(
                    width: box.maxWidth * k,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [pillViolet, pillCyan]),
                    ),
                  ),
                ),
              ]);
            }),
          ]),
        ),
    ]);
  }
}

/// A ring of shares with the total in the middle, and a legend with counts.
class _Donut extends StatelessWidget {
  final ChartData d;
  const _Donut(this.d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (d.rows.isEmpty || d.series.isEmpty) return Text(_empty(context));
    final key = d.series.first.key;
    final values = [for (final r in d.rows) math.max(0.0, r.values[key] ?? 0)];
    final total = values.fold<double>(0, (a, b) => a + b);
    Color color(int i) => chartColors[i % chartColors.length];
    return Row(children: [
      SizedBox.square(
        dimension: 132,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, k, _) => CustomPaint(
            painter: _DonutPainter(values, [for (var i = 0; i < values.length; i++) color(i)], k, theme.colorScheme.surfaceContainerHighest),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(chartNumber(total, d.format, short: true), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(d.series.first.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, r) in d.rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color(i), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium)),
                Text(chartNumber(values[i], d.format), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double k;
  final Color track;
  _DonutPainter(this.values, this.colors, this.k, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.04;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * k;
      if (sweep > gap) {
        canvas.drawArc(rect, start + gap / 2, sweep - gap, false, Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.k != k || old.values != values;
}

/// Columns over time (or groups), the series stacked, with a legend.
class _Columns extends StatelessWidget {
  final ChartData d;
  const _Columns(this.d);

  static String _xLabel(String x, String label) {
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(x);
    if (m != null) return DateFormat.MMM('en_US').format(DateTime(int.parse(m[1]!), int.parse(m[2]!)));
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (d.rows.isEmpty || d.series.isEmpty) return Text(_empty(context));
    final totals = [for (final r in d.rows) d.series.fold<double>(0, (a, s) => a + math.max(0, r.values[s.key] ?? 0))];
    final max = totals.fold<double>(0, math.max);
    final colors = [for (var i = 0; i < d.series.length; i++) chartColors[i % chartColors.length]];
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(chartNumber(max, d.format, short: true), style: labelStyle),
      const SizedBox(height: 6),
      SizedBox(
        height: 150,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, k, _) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, r) in d.rows.indexed)
              Expanded(
                child: Tooltip(
                  message: '${_xLabel(r.x, r.label)}: ${chartNumber(totals[i], d.format)}',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: d.rows.length > 8 ? 2 : 5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      for (final (si, s) in d.series.indexed.toList().reversed)
                        Container(
                          height: max <= 0 ? 0 : 150 * k * math.max(0, r.values[s.key] ?? 0) / max,
                          decoration: BoxDecoration(
                            color: colors[si],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(si == d.series.length - 1 ? 4 : 0)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
      Divider(height: 1, color: theme.colorScheme.outlineVariant),
      const SizedBox(height: 6),
      Row(children: [
        for (final (i, r) in d.rows.indexed)
          Expanded(
            child: Text(
              // Many columns: every other label.
              d.rows.length > 8 && i.isOdd ? '' : _xLabel(r.x, r.label),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: labelStyle,
            ),
          ),
      ]),
      if (d.series.length > 1) ...[
        const SizedBox(height: 12),
        _Legend([for (final (i, s) in d.series.indexed) (s.label, colors[i])]),
      ],
    ]);
  }
}

/// Group label down the left, one column per measure.
class _Table extends StatelessWidget {
  final ChartData d;
  const _Table(this.d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (d.rows.isEmpty) return Text(_empty(context));
    final head = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final num = theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Table(
      columnWidths: const {0: FlexColumnWidth(2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          for (final s in d.series)
            Padding(padding: const EdgeInsets.only(left: 10, bottom: 6), child: Text(s.label, textAlign: TextAlign.end, style: head)),
        ]),
        for (final r in d.rows)
          TableRow(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)))),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              ),
              for (final s in d.series) Text(chartNumber(r.values[s.key] ?? 0, d.format), textAlign: TextAlign.end, style: num),
            ],
          ),
      ],
    );
  }
}
