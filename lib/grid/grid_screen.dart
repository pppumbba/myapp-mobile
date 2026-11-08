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
import '../nav/pill_bar.dart' show pillViolet;
import '../screens/screen_view.dart';
import '../stage_query/stage_query_sheet.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/expanding_search.dart';
import '../widgets/speed_dial.dart';
import 'card_slots.dart';
import 'cells.dart';
import 'filter_sheet.dart';
import 'grid_query.dart';
import 'record_card.dart';
import 'swipe_actions.dart';
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
  // Records a pull-to-refresh brought in: they glow once.
  Set<String> _glowIds = const {};
  int _glowGen = 0;

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

  /// Pull to refresh: reloads, then marks the records that weren't there before.
  Future<void> _pullReload() async {
    final pk = primaryKey(_params);
    final before = {for (final r in _rows) '${r[pk]}'};
    await _reload();
    if (!mounted || before.isEmpty) return;
    final fresh = {for (final r in _rows) if (r[pk] != null && !before.contains('${r[pk]}')) '${r[pk]}'};
    if (fresh.isNotEmpty) {
      setState(() {
        _glowIds = fresh;
        _glowGen++;
      });
    }
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
        await _delete(a.formMetaId!, id);
        return;
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

  /// Asks, then deletes; true when the record is gone. [reload] refreshes the list afterwards.
  Future<bool> _delete(int formMetaId, String id, {bool reload = true}) async {
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
    if (ok != true || !mounted) return false;
    try {
      await ref.read(apiClientProvider).delete('/metas/$formMetaId/data/$id');
      if (mounted && reload) _reload();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiError ? e.message : l.somethingWrong)));
      return false;
    }
  }

  /// The buttons a swiped card shows: up to three, delete outermost; extra actions go behind More.
  List<SwipeAction> _swipeActions(Map<String, dynamic> row, List<MetaAction> rowActs) {
    final l = AppLocalizations.of(context);
    final del = rowActs.where((a) => a.action == 'delete').firstOrNull;
    final others = [for (final a in rowActs) if (a != del) a];
    final room = del == null ? 3 : 2;
    final shown = others.length > room ? others.take(room - 1).toList() : others;
    SwipeAction button(MetaAction a) => SwipeAction(
          icon: _actionIcon(a),
          label: a.label ?? a.action ?? '',
          color: a.action == 'edit' ? pillViolet : const Color(0xFF5B5A7A),
          onPressed: () async {
            await _run(a, row);
            return false;
          },
        );
    return [
      for (final a in shown) button(a),
      if (others.length > room)
        SwipeAction(
          icon: Icons.more_horiz,
          label: l.more,
          color: const Color(0xFF8C8AA8),
          onPressed: () async {
            await _rowSheet(row, rowActs);
            return false;
          },
        ),
      if (del != null)
        SwipeAction(
          icon: Icons.delete_outline,
          label: del.label ?? l.delete,
          color: deleteRed,
          destructive: true,
          onPressed: () async {
            final id = actionRecordId(del, row, primaryKey(_params));
            if (del.formMetaId == null || id == null) {
              _openOnWeb();
              return false;
            }
            return _delete(del.formMetaId!, id, reload: false);
          },
        ),
    ];
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
    // With an add button and more than one thing to start, the + opens them all (the ⋮ menu goes).
    final dial = add == null ? const <MetaAction>[] : [...addActions(all, can: _can, gridMetaId: widget.metaId), ...menu];
    final useDial = dial.length > 1;
    final filters = _filters;
    final slots = _slots;

    return Scaffold(
      floatingActionButton: add == null
          ? null
          : SpeedDialFab(
              tooltip: add.label ?? l.add,
              onPressed: () => _add(add),
              items: !useDial
                  ? const []
                  : [
                      for (final (i, a) in dial.indexed)
                        SpeedDialItem(
                          icon: a.action == 'add' ? (a.iconCls == null ? Icons.note_add_outlined : menuIcon(a.iconCls)) : _actionIcon(a),
                          label: a.label ?? a.action ?? '',
                          color: speedDialColors[i % speedDialColors.length],
                          onTap: () => a.action == 'add' ? _add(a) : _run(a, null),
                        ),
                    ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(children: [
              Expanded(child: ExpandingSearch(controller: _searchText, onChanged: _onSearch, hint: l.search, alwaysOpen: true)),
              if (menu.isNotEmpty && !useDial)
                PopupMenuButton<MetaAction>(
                  tooltip: l.actions,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (a) => _run(a, null),
                  itemBuilder: (_) => [for (final a in menu) PopupMenuItem(value: a, child: Text(a.label ?? a.action ?? ''))],
                ),
              if (menu.isEmpty || useDial) const SizedBox(width: 12),
            ]),
          ),
          if (filters.isNotEmpty || _q.filter.isNotEmpty) _filterRow(filters, l),
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

  /// One chip per filter field, scrolling sideways: tap to pick that field's value, × to drop it.
  /// The first chip opens every filter at once (with counts); a filter set some other way
  /// (a preset or a drill-down) gets its own removable chip at the end.
  Widget _filterRow(List<MetaParam> filters, AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final paths = {for (final f in filters) pathOf(f)};
    Widget chip({required String label, required bool on, VoidCallback? onTap, VoidCallback? onClear}) => InputChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(label, overflow: TextOverflow.ellipsis)),
            if (!on) const Icon(Icons.arrow_drop_down, size: 18),
          ]),
          selected: on,
          showCheckmark: false,
          selectedColor: pillViolet.withValues(alpha: 0.28),
          side: BorderSide(color: on ? pillViolet : scheme.outlineVariant),
          onPressed: onTap,
          onDeleted: on ? onClear : null,
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (filters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: l.filter,
                  onPressed: _openFilters,
                  icon: Badge(isLabelVisible: _q.filter.isNotEmpty, label: Text('${_q.filter.length}'), child: const Icon(Icons.tune, size: 20)),
                ),
              ),
            ),
          for (final fp in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: chip(
                  label: switch (_q.filter[pathOf(fp)]) {
                    final v? => '${fp.label}: ${filterValueText(fp, v, l: l, lookups: ref.read(lookupServiceProvider))}',
                    null => fp.label,
                  },
                  on: _q.filter.containsKey(pathOf(fp)),
                  onTap: () => _openFilter(fp),
                  onClear: () => _removeFilter(pathOf(fp)),
                ),
              ),
            ),
          for (final e in _q.filter.entries)
            if (!paths.contains(e.key))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(child: chip(label: '${_labelOf(e.key)}: ${e.value}', on: true, onClear: () => _removeFilter(e.key))),
              ),
        ],
      ),
    );
  }

  /// The filter sheet for one field; only that field's value changes.
  Future<void> _openFilter(MetaParam fp) async {
    final path = pathOf(fp);
    final picked = await showFilterSheet(context, gridMetaId: widget.metaId, filters: [fp], values: _q.filter, query: _q.toQuery());
    if (picked == null || !mounted) return;
    _q.filter = {..._q.filter}..remove(path);
    if (picked[path] case final v? when v.isNotEmpty) _q.filter = {..._q.filter, path: v};
    _sheetShownForMissing = false;
    _reload();
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
    Widget scrollable(Widget child) => PullRefresh(
          onRefresh: _pullReload,
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
    return PullRefresh(
      onRefresh: _pullReload,
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
          final id = row[primaryKey(_params)];
          return Padding(
            key: id == null ? ObjectKey(row) : ValueKey('$id'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SwipeActions(
              actions: _swipeActions(row, rowActs),
              // The card has flown off: drop it here, then refresh in the background.
              onRemoved: () {
                setState(() => _rows.remove(row));
                _reload();
              },
              child: NewRowGlow(
                active: _glowIds.contains('$id'),
                generation: _glowGen,
                child: RecordCard(
                  slots: slots,
                  row: row,
                  margin: EdgeInsets.zero,
                  lookupText: _lookupText,
                  onTap: () => _tap(row, all),
                  onMore: rowActs.isEmpty ? null : () => _rowSheet(row, rowActs),
                ),
              ),
            ),
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
