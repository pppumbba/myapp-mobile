import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../form/fields.dart';
import '../form/values.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../widgets/drop_toast.dart';
import '../widgets/error_banner.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/pull_refresh.dart' show RefreshRing;
import '../widgets/row_group.dart';
import '../widgets/snap_sheet.dart';
import '../widgets/skeleton.dart';

/// Port of the web StageQueryView as a bottom sheet: the params as form rows, Check (dry run), then
/// Run, which closes the sheet with a toast like a form save.
/// Resolves to true when the query ran for real, so the caller can refresh.
Future<bool> runStageQuery(
  BuildContext context, {
  required int stageQueryMetaId,
  required Map<String, String> params,
}) async {
  var ran = false;
  await showSnapSheet<void>(
    context,
    initial: SnapHeight.half,
    builder: (_) => StageQuerySheet(stageQueryMetaId: stageQueryMetaId, defaults: params, onRan: () => ran = true),
  );
  return ran;
}

class StageQuerySheet extends ConsumerStatefulWidget {
  final int stageQueryMetaId;
  final Map<String, String> defaults;
  final VoidCallback? onRan;
  const StageQuerySheet({super.key, required this.stageQueryMetaId, this.defaults = const {}, this.onRan});

  @override
  ConsumerState<StageQuerySheet> createState() => _StageQuerySheetState();
}

class _StageQuerySheetState extends ConsumerState<StageQuerySheet> {
  Values? _values;
  List<MetaParam> _inputs = const [];
  int? _checked; // affected rows of the last dry run, cleared by any change
  String? _message;
  bool _error = false;
  bool _busy = false;
  String? _name;

  void _init(MetaDef def) {
    if (_values != null) return;
    _name = def.meta.name;
    final s = ref.read(sessionProvider);
    final session = ref.read(sessionProvider.notifier);
    _inputs = [...def.params.where((p) => p.isShow)]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    _values = {
      for (final p in _inputs)
        pathOf(p): widget.defaults[pathOf(p)] ??
            fillTokens(p.defaultValue ?? '', session: session.sessionValue, user: s.user),
    };
  }

  Future<void> _call(bool dryRun) async {
    // Two taps in one frame both get here before the buttons rebuild disabled.
    if (_busy) return;
    _busy = true;
    final l = AppLocalizations.of(context);
    setState(() {
      _message = null;
      _error = false;
    });
    try {
      final r = await ref.read(apiClientProvider).post<dynamic>(
        '/metas/${widget.stageQueryMetaId}/run',
        {'params': _values, 'dry_run': dryRun},
      );
      final affected = r is Map && r['affected'] is num ? (r['affected'] as num).toInt() : 0;
      if (!mounted) return;
      setState(() {
        if (dryRun) {
          _checked = affected;
          _message = affected == 0 ? l.stageNothing : l.stageWillChange(affected);
        } else {
          _checked = null;
          widget.onRan?.call();
        }
      });
      if (!dryRun) {
        // Like a form save: the toast says what happened and the sheet goes.
        showDropToast(context, title: l.stageDone(affected), body: _name, icon: Icons.check_rounded);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = e is ApiError ? e.message : l.stageFailed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final def = ref.watch(metaDefProvider(widget.stageQueryMetaId));
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom;
    return def.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(height: 200, child: FormSkeleton(fields: 2))),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ErrorBanner(message: e is ApiError ? e.message : l.somethingWrong),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SoftButton(onPressed: () => ref.invalidate(metaDefProvider(widget.stageQueryMetaId)), child: Text(l.retry)),
          ),
        ]),
      ),
      data: (d) {
        _init(d);
        final values = _values!;
        final message = _message;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(d.meta.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                ),
                if (_inputs.isNotEmpty)
                  // The form's rows: one rounded block.
                  RowGroup(indent: 14, children: [
                    for (final p in _inputs)
                      FieldInput(
                        p: p,
                        value: values[pathOf(p)],
                        readOnly: _busy,
                        row: true,
                        onChanged: (v) => setState(() {
                          values[pathOf(p)] = v;
                          _checked = null;
                          _message = null;
                        }),
                      ),
                  ]),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _error
                        ? ErrorBanner(key: ValueKey(message), message: message)
                        : ErrorBanner.info(key: ValueKey(message), message: message, icon: (_checked ?? 0) > 0 ? Icons.playlist_add_check_rounded : Icons.info_outline_rounded),
                  ),
              ]),
            ),
          ),
          // The form's bottom bar pair: Check as the soft side step, Run as the gradient main one.
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
            child: Row(children: [
              Expanded(
                child: SoftButton(
                  onPressed: _busy ? null : () => _call(true),
                  child: _busy && (_checked ?? 0) == 0 ? const RefreshRing(size: 22) : Text(l.check),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  onPressed: !_busy && (_checked ?? 0) > 0 ? () => _call(false) : null,
                  child: _busy && (_checked ?? 0) > 0 ? const RefreshRing(size: 22, onGradient: true) : Text(l.run),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}
