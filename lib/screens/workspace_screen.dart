import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../form/detail_lines.dart';
import '../form/form_screen.dart';
import '../form/lookup.dart';
import '../form/lookup_page.dart';
import '../form/values.dart';
import '../grid/cells.dart';
import '../grid/grid_screen.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../widgets/inchworm_tabs.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/skeleton.dart';
import '../widgets/error_state.dart';
import 'open_on_web.dart';
import 'screen_view.dart';

/// A workspace meta (port of the web `WorkspaceView`): one record and everything about it.
/// ref_meta_id is the record's form; json_config.header names the form fields in the header card
/// and title_field the one that names the record. Each shown param with a ref_meta_id is a section,
/// a swipeable tab, kept to the record by its json_config.scope ({"asset_id": "id"}): a grid shows
/// only this record's rows and adds rows that belong to it.
/// [recordId] comes from a drilldown; opened from the menu the user picks the record first.
class WorkspaceScreen extends ConsumerStatefulWidget {
  final Meta meta;
  final List<MetaParam> params;
  final String? recordId;
  const WorkspaceScreen({super.key, required this.meta, required this.params, this.recordId});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  late String? _picked = widget.recordId;
  Map<String, dynamic>? _record;
  String? _error;
  int _index = 0;
  int _gen = 0;

  int? get _formId => widget.meta.refMetaId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _picked, formId = _formId;
    if (id == null || formId == null) return;
    final gen = ++_gen;
    setState(() => _error = null);
    try {
      final r = await ref.read(apiClientProvider).get<dynamic>('/metas/$formId/data/$id');
      if (!mounted || gen != _gen) return;
      setState(() => _record = r is Map ? Map<String, dynamic>.from(r) : {});
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _error = e is ApiError ? e.message : AppLocalizations.of(context).recordNotLoaded);
    }
  }

  String? _titleField(MetaDef main) {
    final t = widget.meta.jsonConfig['title_field'];
    if (t is String && t.isNotEmpty) return t;
    return main.params.where((p) => p.isLabel).map(pathOf).firstOrNull;
  }

  Future<void> _pick(MetaDef main) async {
    final row = await pickLookup(context, LookupSpec(gridMetaId: main.meta.id, valueField: primaryKey(main.params), displayField: _titleField(main)));
    final id = row?[primaryKey(main.params)];
    if (row == null || id == null || !mounted) return;
    setState(() {
      _picked = '$id';
      _record = null;
      _index = 0;
    });
    _load();
  }

  Future<void> _edit(MetaDef main) async {
    if (await openForm(context, formMetaId: main.meta.id, recordId: _picked)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final formId = _formId;
    if (formId == null) return _Notice(text: l.workspaceNeedsForm);
    final def = ref.watch(metaDefProvider(formId));
    return def.when(
      loading: () => const WorkspaceSkeleton(),
      error: (e, _) => ErrorState.of(context, e, onRetry: () => ref.invalidate(metaDefProvider(formId))),
      data: (main) => _body(main, l),
    );
  }

  Widget _body(MetaDef main, AppLocalizations l) {
    final noun = (main.meta.name ?? '').replaceFirst(RegExp(r' form$', caseSensitive: false), '');
    if (_picked == null) {
      return _Notice(
        text: l.pickToWorkOn(noun.toLowerCase()),
        detail: widget.meta.description,
        action: SizedBox(width: 200, child: GradientButton(onPressed: () => _pick(main), child: Text(l.choose))),
      );
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final record = _record;
    if (record == null) return const WorkspaceSkeleton();

    final session = ref.watch(sessionProvider.notifier);
    ref.watch(sessionProvider.select((s) => s.access));
    final sections = [
      for (final p in [...widget.params]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber)))
        if (p.isShow && p.refMetaId != null && session.can(p.refMetaId, 'view')) p,
    ];
    final index = sections.isEmpty ? 0 : _index.clamp(0, sections.length - 1);
    String label(MetaParam p) => p.labelName?.isNotEmpty == true ? p.labelName! : ref.watch(metaDefProvider(p.refMetaId!)).value?.meta.name ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: _Header(
          noun: noun,
          main: main,
          record: record,
          titleField: _titleField(main),
          header: widget.meta.jsonConfig['header'],
          onEdit: session.can(main.meta.id, 'edit') ? () => _edit(main) : null,
          // Opened from the menu: the record can be changed here.
          onChange: widget.recordId == null ? () => _pick(main) : null,
        ),
      ),
      if (sections.isEmpty)
        Expanded(child: _Notice(text: l.workspaceNoSections))
      else ...[
        if (sections.length > 1)
          InchwormTabBar(labels: [for (final p in sections) label(p)], index: index, onTap: (i) => setState(() => _index = i)),
        Expanded(
          child: SpringPages(
            index: index,
            count: sections.length,
            builder: (_, i) => _Section(
              key: ValueKey('${sections[i].id}-$_picked'),
              section: sections[i],
              record: record,
              recordId: '${record[primaryKey(main.params)] ?? _picked}',
            ),
          ),
        ),
      ],
    ]);
  }
}

/// The record's name and its header fields, two to a row.
class _Header extends ConsumerWidget {
  final String noun;
  final MetaDef main;
  final Map<String, dynamic> record;
  final String? titleField;
  final Object? header;
  final VoidCallback? onEdit;
  final VoidCallback? onChange;
  const _Header({required this.noun, required this.main, required this.record, required this.titleField, required this.header, this.onEdit, this.onChange});

  /// The web's pick: json_config.header in its order, else the first six shown fields.
  List<MetaParam> _fields() {
    final params = [
      for (final p in [...main.params]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber)))
        if (p.isShow && !p.isPrimary && p.dataType != 'detail' && pathOf(p) != titleField) p,
    ];
    final wanted = header;
    if (wanted is! List) return params.take(6).toList();
    return [
      for (final f in wanted)
        ?params.where((p) => pathOf(p) == '$f').firstOrNull,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = titleField == null ? rowLabel(record, null) : '${record[titleField] ?? ''}';
    final fields = _fields();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(noun, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            if (onChange != null) IconButton(tooltip: l.choose, onPressed: onChange, icon: const Icon(Icons.swap_horiz, size: 20)),
            if (onEdit != null) IconButton(tooltip: l.edit, onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
          ]),
          if (fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: LayoutBuilder(
                builder: (_, box) => Wrap(spacing: 12, runSpacing: 8, children: [
                  for (final p in fields)
                    SizedBox(
                      width: (box.maxWidth - 12) / 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                        FieldValueText(p: p, value: record[pathOf(p)], empty: '—', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// One section: its meta, kept to the record by json_config.scope.
class _Section extends ConsumerWidget {
  final MetaParam section;
  final Map<String, dynamic> record;
  final String recordId;
  const _Section({super.key, required this.section, required this.record, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = section.jsonConfig['scope'];
    final scope = <String, String>{
      if (map is Map)
        for (final e in map.entries) '${e.key}': record['${e.value}'] == null ? '' : '${record['${e.value}']}',
    };
    final id = section.refMetaId!;
    return ref.watch(metaDefProvider(id)).when(
          loading: () => const CardListSkeleton(),
          error: (e, _) => ErrorState.of(context, e, onRetry: () => ref.invalidate(metaDefProvider(id))),
          data: (d) => switch (d.meta.type) {
            'datagrid' => GridScreen(metaId: id, fixed: scope),
            // The record itself in another form (as the web's embedded FormView).
            'form' => FormScreen(formMetaId: id, recordId: recordId),
            'tabs' || 'dashboard' => screenFor(d.meta, params: d.params, fixed: scope),
            _ => OpenOnWeb(d.meta),
          },
        );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final String? detail;
  final Widget? action;
  const _Notice({required this.text, this.detail, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
