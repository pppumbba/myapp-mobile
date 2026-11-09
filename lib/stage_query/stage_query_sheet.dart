import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../form/fields.dart';
import '../form/values.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../widgets/snap_sheet.dart';
import '../widgets/pull_refresh.dart';

/// Port of the web StageQueryView as a bottom sheet: one input per param, Check (dry run), then Run.
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
  bool _ran = false;

  void _init(MetaDef def) {
    if (_values != null) return;
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
          _ran = true;
          widget.onRan?.call();
          _message = l.stageDone(affected);
        }
      });
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: def.when(
        loading: () => const SizedBox(height: 160, child: Center(child: RefreshRing())),
        error: (e, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(e is ApiError ? e.message : l.somethingWrong, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => ref.invalidate(metaDefProvider(widget.stageQueryMetaId)), child: Text(l.retry)),
        ]),
        data: (d) {
          _init(d);
          final values = _values!;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(d.meta.name ?? '', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final p in _inputs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FieldInput(
                      p: p,
                      value: values[pathOf(p)],
                      readOnly: _busy,
                      onChanged: (v) => setState(() {
                        values[pathOf(p)] = v;
                        _checked = null;
                        if (!_ran) _message = null;
                      }),
                    ),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_message!, style: TextStyle(color: _error ? theme.colorScheme.error : null)),
                  ),
                Row(
                  children: [
                    if (_ran)
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.close))
                    else
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
                    const Spacer(),
                    OutlinedButton(onPressed: _busy ? null : () => _call(true), child: Text(l.check)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: !_busy && (_checked ?? 0) > 0 ? () => _call(false) : null,
                      child: Text(l.run),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
