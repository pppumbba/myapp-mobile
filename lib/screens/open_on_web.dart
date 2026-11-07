import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';

/// Notice for screens the app cannot show natively yet.
class OpenOnWeb extends StatelessWidget {
  final Meta meta;
  const OpenOnWeb(this.meta, {super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_browser_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(meta.name ?? '', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.openOnWebTitle, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(l.openOnWebBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
