import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../widgets/inchworm_tabs.dart';
import '../widgets/pill_buttons.dart';
import '../meta/defs.dart';
import '../widgets/pull_refresh.dart';
import 'errors.dart';
import 'fields.dart';
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
/// after Save; otherwise (a menu screen) it starts a new record after each save.
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
  Values _values = {};
  Object? _recordId;
  bool _loading = true;
  String? _loadError;
  FieldErrors _errors = const FieldErrors();
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

  Values _startValues(Map<String, dynamic>? record) => initialValues(
        _def!.params,
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
      Map<String, dynamic>? record;
      if (_recordId != null) {
        final r = await _client.get<dynamic>('/metas/${widget.formMetaId}/data/$_recordId');
        record = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      }
      if (!mounted) return;
      setState(() {
        _def = def;
        _fields = [for (final p in formFields(def.params)) if (!widget.fixed.containsKey(pathOf(p))) p];
        _values = _startValues(record);
        _loading = false;
      });
      _scheduleAutonumber(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is ApiError ? e.message : AppLocalizations.of(context).somethingWrong;
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
      final missing = missingRequired(groups[_step].fields, _values, widget.fixed.keys.toSet());
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
    final groups = _groups(l);
    final missing = missingRequired(_fields, _values, widget.fixed.keys.toSet());
    if (missing.isNotEmpty) {
      setState(() => _errors = FieldErrors(banner: l.fillRequired, byField: {for (final m in missing) m: l.fieldRequired}));
      _showErrorGroup(groups);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _errors = const FieldErrors();
    });
    final body = toPayload(_fields, _values, appMetaId: ref.read(appConfigProvider).appMetaId, fixed: widget.fixed);
    try {
      final id = widget.formMetaId;
      if (_recordId == null) {
        await _client.post<dynamic>('/metas/$id/data', body);
      } else {
        await _client.put<dynamic>('/metas/$id/data/$_recordId', body);
      }
      if (!mounted) return;
      _savedAny = true;
      messenger.showSnackBar(SnackBar(content: Text(l.saved)));
      if (!add && widget.popOnSave) {
        navigator.pop(true);
        return;
      }
      // Save and add, or a menu form: start a new record with the same fixed values and defaults.
      setState(() {
        _saving = false;
        _recordId = null;
        _values = _startValues(null);
        _preview = const {};
        _step = 0;
      });
      _scheduleAutonumber(force: true);
    } on ApiError catch (e) {
      if (!mounted) return;
      final mapped = mapErrors(e, {for (final p in _fields) pathOf(p)});
      setState(() {
        _saving = false;
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
    );
  }

  // Not a lazy ListView: every field is built, so an error field low in the form can be scrolled to.
  Widget _list(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ]),
      );

  Widget _body(AppLocalizations l, List<FormGroup> groups) {
    final theme = Theme.of(context);
    final grouped = _isGrouped(groups);
    Widget content;
    if (!grouped) {
      content = _list([for (final p in _fields) _field(p, l)]);
    } else if (_layout == 'sections') {
      content = _list([
        for (final g in groups) ...[
          Text(g.name.isEmpty ? l.general : g.name, style: theme.textTheme.titleMedium),
          for (final p in g.fields) _field(p, l),
        ],
      ]);
    } else {
      final step = _step.clamp(0, groups.length - 1);
      final list = _list([for (final p in groups[step].fields) _field(p, l)]);
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
              builder: (_, i) => _list([for (final p in groups[i].fields) _field(p, l)]),
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
      if (banner != null)
        Container(
          color: theme.colorScheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(banner, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
          ]),
        ),
      Expanded(child: content),
    ]);
  }

  Widget? _bottomBar(AppLocalizations l, List<FormGroup> groups) {
    final wizard = _isGrouped(groups) && _layout == 'wizard';
    final step = groups.isEmpty ? 0 : _step.clamp(0, groups.length - 1);
    final midStep = wizard && step < groups.length - 1;
    final canAdd = _def?.meta.jsonConfig['save_and_add'] != false;
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
      body = const Center(child: RefreshRing());
    } else if (_loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _retry, child: Text(l.retry)),
          ]),
        ),
      );
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
