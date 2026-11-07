import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
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

/// The single switch on `meta.type`: Task 7 fills in the grid, Task 8 the form.
Widget screenFor(Meta meta, {Map<String, String> fixed = const {}, Map<String, String> filters = const {}}) {
  switch (meta.type) {
    case 'datagrid':
      return _ComingSoon(meta); // GridScreen (Task 7)
    case 'form':
      return _ComingSoon(meta); // FormScreen (Task 8)
    default:
      return OpenOnWeb(meta);
  }
}

class _ComingSoon extends StatelessWidget {
  final Meta meta;
  const _ComingSoon(this.meta);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(meta.name ?? '', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l.comingSoon),
            ],
          ),
        ),
      ),
    );
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
