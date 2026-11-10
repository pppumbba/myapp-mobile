import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../widgets/error_banner.dart';
import '../widgets/inchworm_tabs.dart';
import '../widgets/pill_buttons.dart';
import '../meta/defs.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/row_group.dart';
import '../widgets/skeleton.dart';
import '../widgets/drop_toast.dart';
import '../widgets/error_state.dart';
import 'criteria.dart';
import 'detail_lines.dart';
import 'errors.dart';
import 'fields.dart';
import 'file_field.dart';
import 'lines.dart';
import 'values.dart';

/// Opens a form full screen: a new record, or [recordId] to edit (or view when [readOnly]).
/// Resolves to true when something was saved.
Future<bool> openForm(
  BuildContext context, {
  required int formMetaId,
  Object? recordId,
  Map<String, String> fixed = const {},
  Map<String, String> defaults = const {},
  bool readOnly = false,
}) async {
  // On the root navigator, so the form covers the shell's app bar and tabs (as the drilldown does).
  final saved = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(
    builder: (_) => FormScreen(
      formMetaId: formMetaId,
      recordId: recordId,
      fixed: fixed,
      defaults: defaults,
      readOnly: readOnly,
      popOnSave: true,
    ),
  ));
  return saved ?? false;
}

/// A form meta as a native screen. [fixed] values are hidden and always sent; [defaults] start a
/// new record. With [popOnSave] (opened by [openForm]) it has its own app bar and closes with true
/// after Save; otherwise a menu screen starts a new record after each save, and a record shown in
/// place (a workspace section) stays on it.
/// Detail params show as sections of lines (each line edited on its own page, up to three deep), a
/// one-to-one as fields of its own; json_config.criteria decides which ones apply.
class FormScreen extends ConsumerStatefulWidget {
  final int formMetaId;
  final Object? recordId;
  final Map<String, String> fixed;
  final Map<String, String> defaults;
  final bool readOnly;
  final bool popOnSave;

  const FormScreen({
    super.key,
    required this.formMetaId,
    this.recordId,
    this.fixed = const {},
    this.defaults = const {},
    this.readOnly = false,
    this.popOnSave = false,
  });

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> with TickerProviderStateMixin {
  MetaDef? _def;
  List<MetaParam> _fields = const [];

  /// File fields with an upload still going; saving waits for them.
  final _uploading = <String>{};
  Values _values = {};
  Object? _recordId;
  bool _loading = true;
  String? _loadError;
  bool _loadOffline = false; // nothing answered: the error page says so
  FieldErrors _errors = const FieldErrors();
  // Details: their line forms as a tree, the lines by detail field, and line errors by full key.
  List<DetailNode> _tree = const [];
  Map<String, List<Line>> _lines = const {};
  Map<String, String> _lineErrors = const {};
  bool _saving = false;
  bool _savedAny = false;
  int _step = 0;
  // One key per field path, to scroll to the first error.
  final Map<String, GlobalKey> _fieldKeys = {};

  // Autonumber previews of a new record, by field path.
  Map<String, String> _preview = const {};
  Timer? _autoTimer;
  String? _autoKey;
  int _autoGen = 0;

  ApiClient get _client => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _recordId = widget.recordId;
    _load();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  String? _session(String path) {
    final m = ref.read(sessionProvider).sessionValues;
    if (!m.containsKey(path)) return null;
    return m[path] == null ? '' : '${m[path]}';
  }

  /// A line's start values, with the same tokens as the form's own.
  Values _startLine(List<MetaParam> params, Map<String, dynamic>? record) =>
      initialValues(params, record: record, session: _session, user: ref.read(sessionProvider).user);

  Map<String, List<Line>> _startAllLines(Map<String, dynamic>? record) => {for (final n in _tree) n.path: startLines(n, record?[n.path], _startLine)};

  Values _startValues(Map<String, dynamic>? record) => initialValues(
        _def!.params,
        files: true,
        record: record,
        fixed: widget.fixed,
        defaults: widget.defaults,
        session: _session,
        user: ref.read(sessionProvider).user,
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final def = await ref.read(metaDefProvider(widget.formMetaId).future);
      final tree = await loadDetailTree((id) => ref.read(metaDefProvider(id).future), def);
      Map<String, dynamic>? record;
      if (_recordId != null) {
        final r = await _client.get<dynamic>('/metas/${widget.formMetaId}/data/$_recordId');
        record = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      }
      if (!mounted) return;
      setState(() {
        _def = def;
        _fields = [for (final p in formFields(def.params, files: true)) if (!widget.fixed.containsKey(pathOf(p))) p];
        _values = _startValues(record);
        _tree = tree;
        _lines = _startAllLines(record);
        _loading = false;
      });
      _scheduleAutonumber(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is ApiError ? e.message : AppLocalizations.of(context).somethingWrong;
        _loadOffline = e is ApiError && e.status == 0;
      });
    }
  }

  void _retry() {
    ref.invalidate(metaDefProvider(widget.formMetaId));
    _load();
  }

  // --- Autonumber ---------------------------------------------------------------------------

  List<MetaParam> get _autos => [for (final p in _fields) if (isAutoReadOnly(p)) p];

  void _scheduleAutonumber({bool force = false}) {
    if (_recordId != null || widget.readOnly) return;
    final autos = _autos;
    if (autos.isEmpty) return;
    final deps = {for (final p in autos) ...autonumberFields(autonumberOf(p)!)}.toList();
    final key = jsonEncode([for (final d in deps) '${_values[d] ?? ''}']);
    if (!force && key == _autoKey) return;
    _autoKey = key;
    _autoTimer?.cancel();
    final gen = ++_autoGen;
    _autoTimer = Timer(const Duration(milliseconds: 250), () async {
      final values = {
        for (final d in deps)
          if ((_values[d] ?? '') != '') d: '${_values[d]}',
      };
      Map<String, String> next;
      try {
        final r = await _client.get<dynamic>('/metas/${widget.formMetaId}/autonumber', query: {'values': values});
        next = r is Map ? {for (final e in r.entries) '${e.key}': '${e.value}'} : {};
      } catch (_) {
        next = {};
      }
      if (mounted && gen == _autoGen) setState(() => _preview = next);
    });
  }

  // --- Values, groups, steps ----------------------------------------------------------------

  void _change(String path, Object v) {
    setState(() {
      _values = {..._values, path: v};
      if (_errors.byField.containsKey(path)) {
        _errors = FieldErrors(banner: _errors.banner, byField: {..._errors.byField}..remove(path));
      }
    });
    _scheduleAutonumber();
  }

  String? get _layout {
    final l = _def?.meta.jsonConfig['layout'];
    return formLayouts.contains(l) ? l as String : null;
  }

  List<FormGroup> _groups(AppLocalizations l) => _layout == null ? const [] : formGroups(_fields, generalName: l.general);

  bool _isGrouped(List<FormGroup> g) => g.length > 1 || (g.length == 1 && g.first.name != '');

  // --- Details ------------------------------------------------------------------------------

  /// Header fields the lines add up into: total_field -> the current sum.
  Map<String, double> get _totals => {for (final n in _tree) if (n.totalField != null) n.totalField!: linesTotal(n, _lines[n.path] ?? const [])};

  /// Blocks nothing: worked out, not typed, and the fixed ones are hidden.
  Set<String> get _notChecked => {...widget.fixed.keys, ..._totals.keys};

  /// What a detail's criteria can use (Criteria::userVars), then the fixed and typed values.
  Map<String, Object?> get _criteriaVars {
    final s = ref.read(sessionProvider);
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final roles = s.user?['roles'];
    return {
      ...s.sessionValues,
      'sessionUserId': s.user?['id'],
      'sessionUserName': s.user?['name'],
      'sessionUserEmail': s.user?['email'],
      'roleId': [if (roles is List) for (final r in roles) r is Map ? r['id'] : r],
      'today': ymd(now),
      'now': '${ymd(now)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
      'appMetaId': ref.read(appConfigProvider).appMetaId,
      ...widget.fixed,
      ..._values,
    };
  }

  bool _applies(DetailNode n, Map<String, Object?> vars) {
    try {
      return criteriaPasses(n.criteria, vars);
    } on CriteriaError {
      return false;
    }
  }

  /// The details a save takes with these values; one whose criteria can't be read is left out.
  List<DetailNode> get _shown {
    final vars = _criteriaVars;
    return [for (final n in _tree) if (_applies(n, vars)) n];
  }

  void _setLines(String path, List<Line> lines) => setState(() {
        _lines = {..._lines, path: lines};
        // A changed detail's messages are stale now; the save sends them again if still wrong.
        _lineErrors = {for (final e in _lineErrors.entries) if (!e.key.startsWith('$path.')) e.key: e.value};
      });

  Widget _detail(DetailNode n) {
    final lines = _lines[n.path] ?? const [];
    if (n.isOne) {
      return OneSection(
        key: ValueKey('detail-${n.path}'),
        node: n,
        line: lines.firstOrNull ?? blankLine(n, _startLine),
        onChanged: (one) => _setLines(n.path, [one]),
        errors: _lineErrors,
        readOnly: widget.readOnly,
      );
    }
    return DetailSection(
      key: ValueKey('detail-${n.path}'),
      node: n,
      lines: lines,
      onChanged: (next) => _setLines(n.path, next),
      errors: _lineErrors,
      readOnly: widget.readOnly,
      start: _startLine,
    );
  }

  /// The details of group [i]: by their json_config.group; the ungrouped go with the first group,
  /// and one whose group has no fields with the last.
  List<Widget> _detailsIn(List<FormGroup> groups, int i, List<DetailNode> shown) {
    final names = {for (final g in groups) g.name.toLowerCase()};
    bool here(DetailNode n) {
      final g = groupOf(n.detail).toLowerCase();
      if (g == '') return i == 0;
      return g == groups[i].name.toLowerCase() || (!names.contains(g) && i == groups.length - 1);
    }

    return [for (final n in shown) if (here(n)) _detail(n)];
  }

  void _goTo(int i) {
    setState(() => _step = i);
  }

  /// Shows the first group holding an error, then scrolls its first error field into view.
  void _showErrorGroup(List<FormGroup> groups) {
    if (_isGrouped(groups)) {
      final i = groups.indexWhere((g) => g.fields.any((p) => _errors.byField.containsKey(pathOf(p))));
      if (i >= 0) _goTo(i);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final p in _fields) {
        if (!_errors.byField.containsKey(pathOf(p))) continue;
        final ctx = _fieldKeys[pathOf(p)]?.currentContext;
        if (ctx == null) continue; // in another tab or step
        Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
        return;
      }
    });
  }

  void _next(List<FormGroup> groups) {
    final l = AppLocalizations.of(context);
    if (!widget.readOnly) {
      final missing = missingRequired(groups[_step].fields, _values, _notChecked, files: true);
      if (missing.isNotEmpty) {
        setState(() => _errors = FieldErrors(byField: {for (final m in missing) m: l.fillBeforeNext}));
        return;
      }
    }
    setState(() => _errors = const FieldErrors());
    _goTo(_step + 1);
  }

  // --- Save ---------------------------------------------------------------------------------

  Future<void> _submit({required bool add}) async {
    // Two taps in one frame both get here before the button rebuilds disabled.
    if (_saving) return;
    final l = AppLocalizations.of(context);
    if (_uploading.isNotEmpty) {
      showDropToast(context, title: l.filesUploading, icon: Icons.hourglass_top_rounded);
      return;
    }
    final groups = _groups(l);
    final missing = missingRequired(_fields, _values, _notChecked, files: true);
    if (missing.isNotEmpty) {
      setState(() => _errors = FieldErrors(banner: l.fillRequired, byField: {for (final m in missing) m: l.fieldRequired}));
      _showErrorGroup(groups);
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _errors = const FieldErrors();
    });
    final body = toPayload(_fields, _values, appMetaId: ref.read(appConfigProvider).appMetaId, fixed: widget.fixed, files: true);
    _totals.forEach((field, sum) => body[field] = round2(sum));
    for (final n in _shown) {
      body[n.path] = detailPayload(n, _lines[n.path] ?? const []);
    }
    try {
      final id = widget.formMetaId;
      if (_recordId == null) {
        await _client.post<dynamic>('/metas/$id/data', body);
      } else {
        await _client.put<dynamic>('/metas/$id/data/$_recordId', body);
      }
      if (!mounted) return;
      _savedAny = true;
      showDropToast(context, title: l.saved, body: _def?.meta.name, icon: Icons.check_rounded);
      if (!add && widget.popOnSave) {
        navigator.pop(true);
        return;
      }
      if (!add && widget.recordId != null) {
        // A record shown in place: stay on it, with its lines as saved (new ones now have ids).
        setState(() => _saving = false);
        _load();
        return;
      }
      // Save and add, or a menu form: start a new record with the same fixed values and defaults.
      setState(() {
        _saving = false;
        _recordId = null;
        _values = _startValues(null);
        _lines = _startAllLines(null);
        _lineErrors = const {};
        _preview = const {};
        _step = 0;
      });
      _scheduleAutonumber(force: true);
    } on ApiError catch (e) {
      if (!mounted) return;
      final mapped = mapErrors(e, {for (final p in _fields) pathOf(p)});
      setState(() {
        _saving = false;
        _lineErrors = {
          for (final err in e.errors.entries)
            if (err.value.isNotEmpty && _tree.any((n) => err.key == n.path || err.key.startsWith('${n.path}.'))) err.key: err.value.first,
        };
        // Every key under its field: still say so at the top, or Save looks like it did nothing.
        _errors = mapped.banner == null && mapped.byField.isNotEmpty
            ? FieldErrors(banner: l.fixErrors, byField: mapped.byField)
            : mapped;
      });
      _showErrorGroup(groups);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = FieldErrors(banner: l.somethingWrong);
      });
    }
  }

  // --- Build --------------------------------------------------------------------------------

  Widget _field(MetaParam p, AppLocalizations l) =>
      KeyedSubtree(key: _fieldKeys.putIfAbsent(pathOf(p), GlobalKey.new), child: _input(p, l));

  Widget _input(MetaParam p, AppLocalizations l) {
    final path = pathOf(p);
    final error = _errors.byField[path];
    if (isFileField(p)) {
      return FileField(
        key: ValueKey(path),
        p: p,
        formMetaId: widget.formMetaId,
        value: _values[path],
        error: error,
        readOnly: widget.readOnly,
        onChanged: (v) => _change(path, v),
        onBusy: (busy) => busy ? _uploading.add(path) : _uploading.remove(path),
      );
    }
    final total = _totals[path];
    if (total != null) {
      // Worked out from the lines, as the web does; the server sums them again.
      return FieldInput(key: ValueKey(path), p: p, value: totalText(total), onChanged: (_) {}, readOnly: true, optional: true, error: error, row: true);
    }
    if (isAutoReadOnly(p)) {
      final isNew = _recordId == null;
      return FieldInput(
        key: ValueKey(path),
        p: p,
        value: isNew ? (_preview[path] ?? (widget.readOnly ? '' : '…')) : _values[path],
        onChanged: (_) {},
        readOnly: true,
        optional: true,
        error: error,
        hint: widget.readOnly ? null : (isNew ? l.autonumberNext : l.autonumberExisting),
        row: true,
      );
    }
    return FieldInput(
      key: ValueKey(path),
      p: p,
      value: _values[path],
      error: error,
      readOnly: widget.readOnly,
      optional: autonumberOf(p) != null,
      onChanged: (v) => _change(path, v),
      row: true,
    );
  }

  /// Fields as rows of one rounded block, like the account page; nothing when there are none.
  List<Widget> _block(Iterable<MetaParam> fields, AppLocalizations l) {
    final rows = [for (final p in fields) _field(p, l)];
    return rows.isEmpty ? const [] : [RowGroup(indent: 14, children: rows)];
  }

  // Not a lazy ListView: every field is built, so an error field low in the form can be scrolled to.
  Widget _list(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Headings bring their own spacing.
          for (final c in children) c is RowGroupHeading ? c : Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ]),
      );

  Widget _body(AppLocalizations l, List<FormGroup> groups) {
    final theme = Theme.of(context);
    final grouped = _isGrouped(groups);
    final shown = _shown;
    Widget content;
    if (!grouped) {
      content = _list([..._block(_fields, l), for (final n in shown) _detail(n)]);
    } else if (_layout == 'sections') {
      content = _list([
        for (final (i, g) in groups.indexed) ...[
          RowGroupHeading(g.name.isEmpty ? l.general : g.name),
          ..._block(g.fields, l),
          ..._detailsIn(groups, i, shown),
        ],
      ]);
    } else {
      final step = _step.clamp(0, groups.length - 1);
      final list = _list([..._block(groups[step].fields, l), ..._detailsIn(groups, step, shown)]);
      if (_layout == 'tabs') {
        content = Column(children: [
          InchwormTabBar(
            labels: [for (final g in groups) g.name.isEmpty ? l.general : g.name],
            index: step,
            onTap: _goTo,
          ),
          Expanded(
            child: SpringPages(
              index: step,
              count: groups.length,
              builder: (_, i) => _list([..._block(groups[i].fields, l), ..._detailsIn(groups, i, shown)]),
            ),
          ),
        ]);
      } else {
        final name = groups[step].name.isEmpty ? l.general : groups[step].name;
        content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.stepOf(step + 1, groups.length), style: theme.textTheme.labelMedium),
              Text(name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (step + 1) / groups.length),
            ]),
          ),
          Expanded(child: list),
        ]);
      }
    }
    final banner = _errors.banner;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        // Fade and slide only: the banner takes its height at once, so scrolling to the first
        // error field isn't undone by the list shrinking afterwards.
        transitionBuilder: (child, animation) {
          final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(position: Tween(begin: const Offset(0, -0.25), end: Offset.zero).animate(eased), child: child),
          );
        },
        layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
        child: banner == null ? const SizedBox(width: double.infinity) : ErrorBanner(key: ValueKey(banner), message: banner),
      ),
      Expanded(child: content),
    ]);
  }

  Widget? _bottomBar(AppLocalizations l, List<FormGroup> groups) {
    final wizard = _isGrouped(groups) && _layout == 'wizard';
    final step = groups.isEmpty ? 0 : _step.clamp(0, groups.length - 1);
    final midStep = wizard && step < groups.length - 1;
    // A record shown in place (a workspace section) saves itself only.
    final canAdd = _def?.meta.jsonConfig['save_and_add'] != false && (widget.popOnSave || widget.recordId == null);
    final buttons = <Widget>[
      // The confirm dialog's pair: a soft pill for the side step, the gradient pill for the main one.
      if (wizard && step > 0) SoftButton(onPressed: _saving ? null : () => _goTo(step - 1), child: Text(l.back)),
      if (midStep)
        GradientButton(onPressed: () => _next(groups), child: Text(l.next))
      else if (!widget.readOnly) ...[
        if (canAdd) SoftButton(onPressed: _saving ? null : () => _submit(add: true), child: Text(l.saveAndAdd)),
        GradientButton(
          onPressed: _saving ? null : () => _submit(add: false),
          child: _saving
              ? const RefreshRing(size: 22, onGradient: true)
              : Text(l.save),
        ),
      ],
    ];
    if (buttons.isEmpty) return null; // a read-only form without steps
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: b)],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget body;
    Widget? bar;
    if (_loading) {
      body = const FormSkeleton();
    } else if (_loadError != null) {
      body = ErrorState(message: _loadError!, offline: _loadOffline, onRetry: _retry);
    } else {
      final groups = _groups(l);
      body = _body(l, groups);
      bar = _bottomBar(l, groups);
    }
    final scaffold = Scaffold(
      appBar: widget.popOnSave ? AppBar(title: Text(_def?.meta.name ?? '')) : null,
      body: body,
      bottomNavigationBar: bar,
    );
    if (!widget.popOnSave) return scaffold;
    // After a Save and add, going back still tells the opener something was saved.
    return PopScope<bool>(
      canPop: !_savedAny,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: scaffold,
    );
  }
}
