import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../grid/card_slots.dart';
import '../grid/record_card.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import 'lookup.dart';

/// Opens the lookup grid full screen; resolves to the tapped row, or null when dismissed.
Future<Map<String, dynamic>?> pickLookup(BuildContext context, LookupSpec s, {Map<String, String> filters = const {}}) =>
    // On the root navigator, so the picker covers the shell's app bar and tabs.
    Navigator.of(context, rootNavigator: true).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => LookupPage(spec: s, filters: filters)));

class LookupPage extends ConsumerStatefulWidget {
  final LookupSpec spec;
  final Map<String, String> filters;
  const LookupPage({super.key, required this.spec, this.filters = const {}});

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
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() {
    _gen++;
    _rows.clear();
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
      final msg = _error is ApiError ? (_error as ApiError).message : l10n.somethingWrong;
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reset, child: Text(l10n.retry)),
          ]),
        ),
      );
    } else if (_rows.isEmpty) {
      body = _loading ? const Center(child: CircularProgressIndicator()) : Center(child: Text(l10n.noResults));
    } else {
      body = ListView.builder(
        controller: _scroll,
        itemCount: _rows.length + (_loading || _error != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _rows.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _error != null
                    ? TextButton(onPressed: _load, child: Text(l10n.retry))
                    : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final row = _rows[i];
          return RecordCard(
            slots: slots,
            row: row,
            onTap: () => Navigator.of(context).pop(row),
            lookupText: (p, v) {
              final sp = cellSpecOf(p);
              return sp == null ? null : svc.cachedText(sp, v);
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l10n.search, border: InputBorder.none),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _reset);
          },
        ),
      ),
      body: body,
    );
  }
}
