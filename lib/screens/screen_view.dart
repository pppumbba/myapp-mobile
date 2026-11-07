import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../form/form_screen.dart';
import '../grid/grid_screen.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import 'open_on_web.dart';

/// Meta types the app shows natively. The menu leaves everything else out.
const supportedTypes = {'datagrid', 'form'};

/// One screen of the app, chosen by the meta type.
class ScreenView extends ConsumerWidget {
  final int metaId;
  final Map<String, String> fixed;
  final Map<String, String> filters;

  const ScreenView({super.key, required this.metaId, this.fixed = const {}, this.filters = const {}});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(metaDefProvider(metaId));
    return def.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LoadError(
        message: e is ApiError ? e.message : AppLocalizations.of(context).somethingWrong,
        onRetry: () => ref.invalidate(metaDefProvider(metaId)),
      ),
      data: (d) => screenFor(d.meta, fixed: fixed, filters: filters),
    );
  }
}

/// The single switch on `meta.type`: a grid as cards; a form opens as a new record.
Widget screenFor(Meta meta, {Map<String, String> fixed = const {}, Map<String, String> filters = const {}}) {
  switch (meta.type) {
    case 'datagrid':
      return GridScreen(key: ValueKey(meta.id), metaId: meta.id, fixed: fixed, filters: filters);
    case 'form':
      return FormScreen(key: ValueKey(meta.id), formMetaId: meta.id, fixed: fixed);
    default:
      return OpenOnWeb(meta);
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry)),
          ],
        ),
      ),
    );
  }
}
