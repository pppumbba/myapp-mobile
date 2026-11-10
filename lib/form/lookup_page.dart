import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../auth/session.dart';
import '../grid/card_slots.dart';
import '../grid/record_card.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../nav/pill_bar.dart' show pillViolet;
import '../widgets/edge_fade.dart';
import '../widgets/expanding_search.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/skeleton.dart';
import '../widgets/error_state.dart';
import 'lookup.dart';

/// Opens the lookup grid full screen; resolves to the tapped row, or null when dismissed.
Future<Map<String, dynamic>?> pickLookup(BuildContext context, LookupSpec s, {Map<String, String> filters = const {}}) =>
    // On the root navigator, so the picker covers the shell's app bar and tabs.
    Navigator.of(context, rootNavigator: true).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => LookupPage(spec: s, filters: filters)));

/// The multi-pick basket (the web `onPickMany`): taps tick records, Add returns them in the order
/// picked; empty when dismissed.
Future<List<Map<String, dynamic>>> pickLookupMany(BuildContext context, LookupSpec s, {Map<String, String> filters = const {}}) async =>
    await Navigator.of(context, rootNavigator: true)
        .push<List<Map<String, dynamic>>>(MaterialPageRoute(builder: (_) => LookupPage(spec: s, filters: filters, multi: true))) ??
    const [];

class LookupPage extends ConsumerStatefulWidget {
  final LookupSpec spec;
  final Map<String, String> filters;
  final bool multi;
  const LookupPage({super.key, required this.spec, this.filters = const {}, this.multi = false});

  @override
  ConsumerState<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends ConsumerState<LookupPage> {
  static const _perPage = 50;
  final _rows = <Map<String, dynamic>>[];
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _page = 0, _last = 1, _gen = 0;
  bool _loading = false;
  Object? _error;
  // The basket (multi): value -> row, in the order picked.
  final _picked = <String, Map<String, dynamic>>{};

  void _toggle(Map<String, dynamic> row) {
    final v = '${row[widget.spec.valueField]}';
    setState(() => _picked.containsKey(v) ? _picked.remove(v) : _picked[v] = row);
  }

  // --- Drag select (multi) ---------------------------------------------------------------
  // Hold a card, then slide: every card from it to the one under the finger takes the held
  // card's new state (ticked or not); sliding back gives the others their old state again.
  // Near the list's top or bottom edge the list scrolls on by itself.

  final _listKey = GlobalKey();
  final _itemKeys = <int, GlobalKey>{};
  int? _dragFrom, _dragTo;
  bool _dragTick = true;
  Map<String, Map<String, dynamic>> _beforeDrag = const {};
  Offset? _dragAt;
  Timer? _edgeScroll;

  /// The row index of the card under a screen point, or null between cards.
  int? _rowAt(Offset global) {
    for (final MapEntry(key: i, value: k) in _itemKeys.entries) {
      if (i >= _rows.length) continue;
      final box = k.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(global)) return i;
    }
    return null;
  }

  void _dragStart(LongPressStartDetails d) {
    final i = _rowAt(d.globalPosition);
    if (i == null) return;
    HapticFeedback.selectionClick();
    _dragFrom = i;
    _dragTo = null;
    _dragTick = !_picked.containsKey('${_rows[i][widget.spec.valueField]}');
    _beforeDrag = Map.of(_picked);
    _dragAt = d.globalPosition;
    _dragOver(i);
  }

  void _dragMove(LongPressMoveUpdateDetails d) {
    if (_dragFrom == null) return;
    _dragAt = d.globalPosition;
    if (_rowAt(d.globalPosition) case final i?) _dragOver(i);
    _edgeScrollIfNear();
  }

  void _dragEnd() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _dragFrom = _dragTo = _dragAt = null;
  }

  /// Rebuilds the basket for the span from the held card to [i], picked outward from the held one.
  void _dragOver(int i) {
    final from = _dragFrom!;
    if (i == _dragTo) return;
    if (_dragTo != null) HapticFeedback.selectionClick();
    _dragTo = i;
    final step = i >= from ? 1 : -1;
    final next = Map.of(_beforeDrag);
    for (var j = from; j != i + step; j += step) {
      final row = _rows[j];
      final v = '${row[widget.spec.valueField]}';
      _dragTick ? next.putIfAbsent(v, () => row) : next.remove(v);
    }
    setState(() => _picked
      ..clear()
      ..addAll(next));
  }

  void _edgeScrollIfNear() {
    final box = _listKey.currentContext?.findRenderObject();
    final at = _dragAt;
    if (box is! RenderBox || at == null || !_scroll.hasClients) return;
    final y = box.globalToLocal(at).dy;
    const edge = 72.0;
    final speed = y < edge ? -(edge - y) / edge : (y > box.size.height - edge ? (y - (box.size.height - edge)) / edge : 0.0);
    if (speed == 0) {
      _edgeScroll?.cancel();
      _edgeScroll = null;
      return;
    }
    _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final pos = _scroll.position;
      final by = box.globalToLocal(_dragAt ?? at).dy;
      final s = by < edge ? -(edge - by) / edge : (by > box.size.height - edge ? (by - (box.size.height - edge)) / edge : 0.0);
      final to = (pos.pixels + s.clamp(-1.0, 1.0) * 18).clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (s == 0 || to == pos.pixels) return;
      pos.jumpTo(to);
      if (_dragAt != null) {
        if (_rowAt(_dragAt!) case final i?) _dragOver(i);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_error == null && _scroll.position.extentAfter < 300) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _edgeScroll?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() {
    _gen++;
    _rows.clear();
    _itemKeys.clear();
    _page = 0;
    _last = 1;
    _error = null;
    _loading = false;
    _load();
  }

  Future<void> _load() async {
    if (_loading || _page >= _last) return;
    final gen = _gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiClientProvider).get<dynamic>('/metas/${widget.spec.gridMetaId}/data', query: {
        'search': _search.text.trim(),
        'per_page': _perPage,
        'page': _page + 1,
        'filter': widget.filters,
      });
      if (!mounted || gen != _gen) return;
      final p = DataPage.fromJson(Map<String, dynamic>.from(r as Map));
      await _prefetch(p.rows);
      if (!mounted || gen != _gen) return;
      setState(() {
        _rows.addAll(p.rows);
        _page = p.currentPage;
        _last = p.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Resolves the page's lookup columns before it shows, as the grid does, so cards never show `#12`.
  Future<void> _prefetch(List<Map<String, dynamic>> rows) async {
    try {
      final def = await ref.read(metaDefProvider(widget.spec.gridMetaId).future);
      final s = cardSlots(def.params);
      final svc = ref.read(lookupServiceProvider);
      await Future.wait([
        for (final p in [?s.title, ?s.subtitle, ?s.badge, ...s.body, ...s.footer])
          if (cellSpecOf(p) case final spec?) svc.prefetch(spec, [for (final r in rows) r[p.paramName]]),
      ]);
    } catch (_) {
      // No definition: the cards still show, with ids.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final def = ref.watch(metaDefProvider(widget.spec.gridMetaId));
    final slots = def.maybeWhen(data: (d) => cardSlots(d.params), orElse: () => CardSlots());
    final svc = ref.read(lookupServiceProvider);

    Widget body;
    if (_error != null && _rows.isEmpty) {
      body = ErrorState.of(context, _error!, onRetry: _reset);
    } else if (_rows.isEmpty) {
      body = _loading ? const CardListSkeleton() : Center(child: Text(l10n.noResults));
    } else {
      body = ListView.builder(
        controller: _scroll,
        itemCount: _rows.length + (_loading || _error != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _rows.length) {
            if (_error == null) return const Shimmer(child: SkeletonCard());
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: SoftButton(onPressed: _load, child: Text(l10n.retry))),
            );
          }
          final row = _rows[i];
          final ticked = widget.multi && _picked.containsKey('${row[widget.spec.valueField]}');
          final card = RecordCard(
            slots: slots,
            row: row,
            onTap: widget.multi ? () => _toggle(row) : () => Navigator.of(context).pop(row),
            lookupText: (p, v) {
              final sp = cellSpecOf(p);
              return sp == null ? null : svc.cachedText(sp, v);
            },
          );
          if (!widget.multi) return EdgeFade(child: card);
          return EdgeFade(child: Stack(key: _itemKeys.putIfAbsent(i, GlobalKey.new), children: [
            card,
            Positioned(
              right: 20,
              bottom: 12,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: ticked ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const CircleAvatar(radius: 11, backgroundColor: pillViolet, child: Icon(Icons.check, size: 15, color: Colors.white)),
                ),
              ),
            ),
          ]));
        },
      );
      if (widget.multi) {
        body = GestureDetector(
          key: _listKey,
          onLongPressStart: _dragStart,
          onLongPressMoveUpdate: _dragMove,
          onLongPressEnd: (_) => _dragEnd(),
          onLongPressCancel: _dragEnd,
          child: body,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        // The grid's search pill, always open.
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ExpandingSearch(
            controller: _search,
            hint: l10n.search,
            alwaysOpen: true,
            autofocus: true,
            height: 44,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _reset);
            },
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: !widget.multi
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Until something is picked: how to pick many at once.
                  if (_picked.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.dragPickHint, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  GradientButton(
                    onPressed: _picked.isEmpty ? null : () => Navigator.of(context).pop(_picked.values.toList()),
                    child: Text(l10n.addPicked(_picked.length)),
                  ),
                ]),
              ),
            ),
    );
  }
}
