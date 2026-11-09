import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../widgets/inchworm_tabs.dart';
import 'screen_view.dart';

/// A tabs meta: its params' screens under the same inchworm strip as a menu section.
class TabsScreen extends ConsumerStatefulWidget {
  final Meta meta;
  final List<MetaParam> params;
  const TabsScreen({super.key, required this.meta, required this.params});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider.notifier);
    ref.watch(sessionProvider.select((s) => s.access));
    final tabs = [
      for (final p in [...widget.params]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber)))
        if (p.refMetaId != null && session.can(p.refMetaId, 'view')) p,
    ];
    if (tabs.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(AppLocalizations.of(context).noScreens)));
    }
    final index = _index.clamp(0, tabs.length - 1);
    // A tab without its own label is called by its screen's name.
    String label(MetaParam p) => p.labelName?.isNotEmpty == true
        ? p.labelName!
        : ref.watch(metaDefProvider(p.refMetaId!)).value?.meta.name ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (tabs.length > 1)
        InchwormTabBar(labels: [for (final p in tabs) label(p)], index: index, onTap: (i) => setState(() => _index = i)),
      Expanded(
        child: SpringPages(
          index: index,
          count: tabs.length,
          builder: (_, i) => ScreenView(key: ValueKey(tabs[i].refMetaId), metaId: tabs[i].refMetaId!),
        ),
      ),
    ]);
  }
}
