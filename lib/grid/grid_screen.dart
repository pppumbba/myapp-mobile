import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../form/form_screen.dart';
import '../form/lookup.dart';
import '../form/values.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../nav/icons.dart';
import '../screens/screen_view.dart';
import '../stage_query/stage_query_sheet.dart';
import 'card_slots.dart';
import 'cells.dart';
import 'filter_sheet.dart';
import 'grid_query.dart';
import 'record_card.dart';
import 'row_actions.dart';

/// A datagrid as a list of cards: search, filter sheet with chips, infinite scroll, Add FAB,
/// row buttons in a bottom sheet. [fixed] values are the grid's scope (always applied) and are
/// passed to its add/edit forms; [filters] are the starting filter values.
class GridScreen extends ConsumerStatefulWidget {
  final int metaId;
  final Map<String, String> fixed;
  final Map<String, String> filters;

  const GridScreen({super.key, required this.metaId, this.fixed = const {}, this.filters = const {}});

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  late final GridQuery _q = GridQuery(filter: {...widget.filters}, scope: {...widget.fixed});
  final _scroll = ScrollController();
  final _searchText = TextEditingController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _rows = [];
  int _lastPage = 1;
  Map<String, dynamic> _footer = const {};
  List<String> _missing = const [];
  bool _loading = false;
  bool _loadingMore = false;
  ApiError? _error;
  int _generation = 0;
  bool _started = false;
  bool _sheetShownForMissing = false;
  // Lookup values whose prefetch finished: a still-missing text then really failed.
  final Set<(LookupSpec, String)> _resolved = {};

  late final ApiClient _client = ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _client.addWriteListener(_onWrite);
  }

  /// Any write clears the lookup cache: resolve the shown rows again (they show … meanwhile, not ids).
  void _onWrite() {
    _resolved.clear();
    final gen = _generation;
    // After the other write listeners (the lookup cache clears itself in one of them).
    scheduleMicrotask(() async {
      if (!mounted || gen != _generation) return;
      await _prefetch(List.of(_rows));
      if (mounted && gen == _generation) setState(() {});
    });
  }

  @override
  void dispose() {
    _client.removeWriteListener(_onWrite);
    _debounce?.cancel();
    _scroll.dispose();
    _searchText.dispose();
    super.dispose();
  }

  MetaDef? get _def => ref.read(metaDefProvider(widget.metaId)).value;
  List<MetaParam> get _params => _def?.params ?? const [];

  bool _can(int? id, String ability) => ref.read(sessionProvider.notifier).can(id, ability);

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _error != null) return;
    if (_q.page >= _lastPage) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  /// Reloads from page 1. Old rows stay visible until the answer lands.
  Future<void> _reload() async {
    final gen = ++_generation;
    _q.page = 1;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page = await _fetch();
      if (gen != _generation || !mounted) return;
      _resolved.clear();
      await _prefetch(page.rows);
      if (gen != _generation || !mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.rows);
        _lastPage = page.lastPage;
        _footer = page.footer;
        _missing = page.missingFilters;
        _loading = false;
      });
      if (_missing.isNotEmpty && !_sheetShownForMissing) {
        _sheetShownForMissing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openFilters();
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (e) {
      if (gen != _generation || !mounted) return;
      setState(() {
        _loading = false;
        // The shown rows belong to the old query: drop them so the full-screen Retry reloads page 1.
        _rows.clear();
        _missing = const [];
        _footer = const {};
        _lastPage = 1;
        _error = e is ApiError ? e : ApiError(-1, AppLocalizations.of(context).somethingWrong);
      });
    }
  }

  Future<void> _loadMore() async {
    final gen = _generation;
    final next = _q.page + 1;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      _q.page = next;
      final page = await _fetch();
      if (gen != _generation || !mounted) return;
      await _prefetch(page.rows);
      if (gen != _generation || !mounted) return;
      setState(() {
        _rows.addAll(page.rows);
        _lastPage = page.lastPage;
        _footer = page.footer;
        _loadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (e) {
      if (gen != _generation || !mounted) return;
      _q.page = next - 1;
      setState(() {
        _loadingMore = false;
        _error = e is ApiError ? e : ApiError(-1, AppLocalizations.of(context).somethingWrong);
      });
    }
  }

  Future<DataPage> _fetch() async {
    final r = await ref.read(apiClientProvider).get<dynamic>('/metas/${widget.metaId}/data', query: _q.toQuery());
    return DataPage.fromJson(Map<String, dynamic>.from(r as Map));
  }

  static LookupSpec? _cellSpec(MetaParam p) => cellSpecOf(p);

  List<MetaParam> get _cardParams {
    final s = _slots;
    return [?s.title, ?s.subtitle, ?s.badge, ...s.body, ...s.footer];
  }

  CardSlots get _slots => cardSlots(_params);

  Future<void> _prefetch(List<Map<String, dynamic>> rows) async {
    final svc = ref.read(lookupServiceProvider);
    final jobs = <Future<void>>[];
    for (final p in _cardParams) {
      final spec = _cellSpec(p);
      if (spec == null) continue;
      final values = [for (final r in rows) r[p.paramName]];
      jobs.add(svc.prefetch(spec, values).then((_) {
        for (final v in values) {
          if (v != null) _resolved.add((spec, '$v'));
        }
      }));
    }
    // Lookup filter values, so their chips show the label, not "…" (filter_as applies here).
    for (final fp in _filters) {
      final v = _q.filter[pathOf(fp)];
      final spec = isLookup(fp) ? lookupSpecOf(fp) : null;
      if (v == null || v.isEmpty || spec == null) continue;
      jobs.add(svc.prefetch(spec, [v]));
    }
    await Future.wait(jobs);
  }

  /// A row's title: the title slot's cell text (lookups and numbers formatted), else rowLabel.
  String _rowTitle(Map<String, dynamic> row) {
    final t = _slots.title;
    final text = t == null ? '' : cellText(t, row, lookupText: _lookupText, l10n: AppLocalizations.of(context));
    return text.isNotEmpty ? text : rowLabel(row, t?.paramName);
  }

  String? _lookupText(MetaParam p, Object? value) {
    final spec = _cellSpec(p);
    if (spec == null) return null;
    final t = ref.read(lookupServiceProvider).cachedText(spec, value);
    if (t != null) return t;
    return _resolved.contains((spec, '$value')) ? '#$value' : '…';
  }

  void _onSearch(String s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _q.search == s) return;
      _q.search = s;
      _reload();
    });
  }

  List<MetaParam> get _filters => filterParams(_params);

  Future<void> _openFilters() async {
    final picked = await showFilterSheet(
      context,
      gridMetaId: widget.metaId,
      filters: _filters,
      values: _q.filter,
      query: _q.toQuery(),
    );
    if (picked == null || !mounted) return;
    _q.filter = picked;
    _sheetShownForMissing = false;
    _reload();
  }

  void _removeFilter(String path) {
    _q.filter = {..._q.filter}..remove(path);
    _sheetShownForMissing = false;
    _reload();
  }

  String _labelOf(String path) =>
      allParams(_params).where((p) => pathOf(p) == path || p.paramName == path).firstOrNull?.label ?? path;

  // ---- actions ----

  Future<void> _afterForm(Future<bool> saved) async {
    if (await saved && mounted) _reload();
  }

  void _add(MetaAction a) {
    if (a.formMetaId == null) return _openOnWeb();
    _afterForm(openForm(context, formMetaId: a.formMetaId!, fixed: widget.fixed));
  }

  void _openOnWeb() {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.openOnWebTitle}. ${l.openOnWebBody}')));
  }

  Future<void> _tap(Map<String, dynamic> row, List<MetaAction> all) async {
    final def = _def;
    if (def == null) return;
    final d = drilldownOf(def.meta.jsonConfig);
    if (d != null) {
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(d.label ?? _rowTitle(row))),
          body: ScreenView(metaId: d.metaId, fixed: drillParams(d.params, row)),
        ),
      ));
      return;
    }
    if (!mounted) return;
    final pk = primaryKey(_params);
    final edit = all.where((a) => a.action == 'edit' && a.formMetaId != null).firstOrNull;
    if (edit != null && canRun(edit, can: _can, gridMetaId: widget.metaId)) {
      return _afterForm(openForm(context, formMetaId: edit.formMetaId!, recordId: actionRecordId(edit, row, pk), fixed: widget.fixed));
    }
    final form = edit ?? all.where((a) => a.action == 'add' && a.formMetaId != null).firstOrNull;
    final id = row[pk];
    if (form != null && id != null) {
      await openForm(context, formMetaId: form.formMetaId!, recordId: actionRecordId(form, row, pk), readOnly: true);
    }
  }

  Future<void> _rowSheet(Map<String, dynamic> row, List<MetaAction> actions) async {
    final picked = await showModalBottomSheet<MetaAction>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(_rowTitle(row), style: Theme.of(ctx).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          for (final a in actions)
            ListTile(
              leading: Icon(_actionIcon(a)),
              title: Text(a.label ?? a.action ?? ''),
              onTap: () => Navigator.of(ctx).pop(a),
            ),
        ]),
      ),
    );
    if (picked != null && mounted) await _run(picked, row);
  }

  IconData _actionIcon(MetaAction a) => switch (a.action) {
        'edit' => Icons.edit_outlined,
        'delete' => Icons.delete_outline,
        'stage_query' => Icons.play_arrow_outlined,
        _ => a.iconCls == null ? Icons.chevron_right : menuIcon(a.iconCls),
      };

  Future<void> _run(MetaAction a, Map<String, dynamic>? row) async {
    final params = row == null ? <String, String>{} : actionParams(a, row);
    final pk = primaryKey(_params);
    switch (a.action) {
      case 'edit':
        final id = row == null ? null : actionRecordId(a, row, pk);
        if (a.formMetaId == null || id == null) return _openOnWeb();
        return _afterForm(openForm(context, formMetaId: a.formMetaId!, recordId: id, fixed: widget.fixed));
      case 'delete':
        final id = row == null ? null : actionRecordId(a, row, pk);
        if (a.formMetaId == null || id == null) return _openOnWeb();
        return _delete(a.formMetaId!, id);
      case 'stage_query':
        if (a.formMetaId == null) return _openOnWeb();
        if (await runStageQuery(context, stageQueryMetaId: a.formMetaId!, params: params) && mounted) _reload();
        return;
    }
    // A form action (or another kind whose target is a form) opens it with the mapped values.
    final target = a.formMetaId;
    if (target == null) return _openOnWeb();
    String? type;
    try {
      type = await ref.read(metaTypeProvider(target).future);
    } catch (_) {}
    if (!mounted) return;
    if (type != 'form') return _openOnWeb();
    return _afterForm(openForm(context, formMetaId: target, defaults: params, fixed: widget.fixed));
  }

  Future<void> _delete(int formMetaId, String id) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/metas/$formMetaId/data/$id');
      if (mounted) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiError ? e.message : l.somethingWrong)));
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final def = ref.watch(metaDefProvider(widget.metaId));
    final acts = ref.watch(actionsProvider(widget.metaId));
    ref.watch(sessionProvider.select((s) => s.access));

    Widget failure(Object e, VoidCallback retry) => _Message(
          text: e is ApiError ? e.message : l.somethingWrong,
          action: FilledButton(onPressed: retry, child: Text(l.retry)),
        );

    if (def.hasError) return failure(def.error!, () => ref.invalidate(metaDefProvider(widget.metaId)));
    if (acts.hasError) return failure(acts.error!, () => ref.invalidate(actionsProvider(widget.metaId)));
    if (!def.hasValue || !acts.hasValue) return const Center(child: CircularProgressIndicator());

    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }

    final all = acts.value!;
    final add = addAction(all, can: _can, gridMetaId: widget.metaId);
    final rowActs = rowActions(all, can: _can, gridMetaId: widget.metaId);
    final menu = toolbarActions(all, can: _can, gridMetaId: widget.metaId);
    final filters = _filters;
    final slots = _slots;

    return Scaffold(
      floatingActionButton: add == null
          ? null
          : FloatingActionButton(tooltip: add.label ?? l.add, onPressed: () => _add(add), child: const Icon(Icons.add)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchText,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.search,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (filters.isNotEmpty)
                IconButton(
                  tooltip: l.filter,
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: _q.filter.isNotEmpty,
                    label: Text('${_q.filter.length}'),
                    child: const Icon(Icons.filter_list),
                  ),
                ),
              if (menu.isNotEmpty)
                PopupMenuButton<MetaAction>(
                  tooltip: l.actions,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (a) => _run(a, null),
                  itemBuilder: (_) => [for (final a in menu) PopupMenuItem(value: a, child: Text(a.label ?? a.action ?? ''))],
                ),
            ]),
          ),
          if (_q.filter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 8, children: [
                for (final e in _q.filter.entries) _chip(e.key, e.value, filters, l),
              ]),
            ),
          if (_footerText(l) case final f? when f.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(child: _list(l, slots, all, rowActs)),
        ],
      ),
    );
  }

  Widget _chip(String path, String value, List<MetaParam> filters, AppLocalizations l) {
    final fp = filters.where((f) => pathOf(f) == path).firstOrNull;
    final text = fp == null ? value : filterValueText(fp, value, l: l, lookups: ref.read(lookupServiceProvider));
    return InputChip(
      label: Text('${fp?.label ?? _labelOf(path)}: $text'),
      onPressed: _openFilters,
      onDeleted: () => _removeFilter(path),
    );
  }

  String? _footerText(AppLocalizations l) {
    if (_footer.isEmpty) return null;
    final parts = <String>[];
    _footer.forEach((field, value) {
      if (value == null) return;
      final p = allParams(_params).where((x) => pathOf(x) == field || x.paramName == field).firstOrNull;
      if (p == null) {
        parts.add('$field: $value');
      } else {
        parts.add('${p.label}: ${cellText(p, {p.paramName: value}, lookupText: _lookupText, l10n: l)}');
      }
    });
    return parts.join(' · ');
  }

  Widget _list(AppLocalizations l, CardSlots slots, List<MetaAction> all, List<MetaAction> rowActs) {
    Widget scrollable(Widget child) => RefreshIndicator(
          onRefresh: _reload,
          child: LayoutBuilder(
            builder: (_, c) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: child),
            ),
          ),
        );

    if (_error != null && _rows.isEmpty) {
      return scrollable(_Message(text: _error!.message, action: FilledButton(onPressed: _reload, child: Text(l.retry))));
    }
    if (_missing.isNotEmpty) {
      return scrollable(_Message(
        text: l.filterFirst(_missing.map(_labelOf).join(', ')),
        action: FilledButton.tonal(onPressed: _openFilters, child: Text(l.filter)),
      ));
    }
    if (_rows.isEmpty) {
      return scrollable(_loading || !_started ? const SizedBox.shrink() : _Message(text: l.noResults));
    }

    final more = _q.page < _lastPage || _loadingMore || _error != null;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: _rows.length + (more ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _rows.length) {
            if (_error != null) {
              return _Message(text: _error!.message, action: FilledButton(onPressed: _loadMore, child: Text(l.retry)));
            }
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final row = _rows[i];
          return RecordCard(
            slots: slots,
            row: row,
            lookupText: _lookupText,
            onTap: () => _tap(row, all),
            onMore: rowActs.isEmpty ? null : () => _rowSheet(row, rowActs),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}
