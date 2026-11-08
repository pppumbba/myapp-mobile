import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../screens/screen_view.dart';
import 'icons.dart';
import 'menu.dart';

const maxTabBranches = 4;

/// Where a signed-in user lands: the first tab.
const landingLocation = '/t/0';
const moreBranchIndex = maxTabBranches;
const moreLocation = '/more';

/// The app menu, built once every viewable ref meta's type is known.
final mobileMenuProvider = FutureProvider<MobileMenu>(retry: noRetry, (ref) async {
  final appId = ref.watch(appConfigProvider).appMetaId;
  final access = ref.watch(sessionProvider.select((s) => s.access));
  bool canView(int id) => access?.can(id, 'view') ?? false;
  final app = await ref.watch(metaDefProvider(appId).future);
  final ids = menuRefIds(app.params).where(canView).toList();
  final types = await Future.wait(ids.map((id) => ref.watch(metaTypeProvider(id).future)));
  final typeOf = {for (var i = 0; i < ids.length; i++) ids[i]: types[i]};
  return flattenMenu(
    app.params,
    canView: canView,
    supported: (id) => supportedTypes.contains(typeOf[id]),
    maxTabs: maxTabBranches,
  );
});

/// Root page of tab branch [index]: the screen of that menu entry.
class TabRoot extends ConsumerWidget {
  final int index;
  const TabRoot(this.index, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(mobileMenuProvider).value;
    if (menu == null || index >= menu.tabs.length) return const SizedBox.shrink();
    final e = menu.tabs[index];
    return ScreenView(key: ValueKey(e.metaId), metaId: e.metaId);
  }
}

/// The More tab: remaining screens as a list with group headers.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(mobileMenuProvider).value;
    if (menu == null) return const SizedBox.shrink();
    final children = <Widget>[];
    String? last;
    for (var i = 0; i < menu.more.length; i++) {
      final e = menu.more[i];
      if (e.group != null && e.group != last) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(e.group!, style: Theme.of(context).textTheme.labelLarge),
        ));
      }
      last = e.group;
      children.add(ListTile(
        leading: Icon(menuIcon(e.item.iconCls)),
        title: Text(e.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('$moreLocation/screen/${e.metaId}'),
      ));
    }
    return ListView(children: children);
  }
}

/// A screen opened from the More list, inside the More tab's own stack.
class MoreScreenPage extends StatelessWidget {
  final int metaId;
  const MoreScreenPage(this.metaId, {super.key});

  @override
  Widget build(BuildContext context) => ScreenView(key: ValueKey(metaId), metaId: metaId);
}

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState routeState;
  const AppShell({super.key, required this.navigationShell, required this.routeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final menu = ref.watch(mobileMenuProvider);
    final appName = ref.watch(sessionProvider.select((s) => s.info?.name)) ?? '';
    final account = IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: l.account,
      onPressed: () => showAccountSheet(context, ref),
    );

    return menu.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(appName), actions: [account]),
        body: const _MenuSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(appName), actions: [account]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e is ApiError ? e.message : l.somethingWrong, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(metaDefProvider);
                  ref.invalidate(metaTypeProvider);
                  ref.invalidate(mobileMenuProvider);
                },
                child: Text(l.retry),
              ),
            ]),
          ),
        ),
      ),
      data: (m) {
        if (m.all.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(appName), actions: [account]),
            body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.noScreens))),
          );
        }
        final branch = navigationShell.currentIndex;
        final onMore = branch == moreBranchIndex;
        final hasMore = m.more.isNotEmpty;
        final destinationCount = m.tabs.length + (hasMore ? 1 : 0);
        // The menu can shrink under the user (access change): leave a branch that no longer exists.
        final branchExists = onMore ? hasMore : branch < m.tabs.length;
        if (!branchExists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) navigationShell.goBranch(0);
          });
        }
        final selected = !branchExists ? 0 : (onMore ? m.tabs.length : branch).clamp(0, destinationCount - 1);

        // The title follows the screen: tab label, "More", or the screen opened from More.
        var title = appName;
        var inMoreScreen = false;
        if (onMore) {
          title = l.more;
          final segs = routeState.uri.pathSegments;
          if (segs.length >= 3 && segs[1] == 'screen') {
            inMoreScreen = true;
            final id = int.tryParse(segs[2]);
            title = m.more.where((e) => e.metaId == id).firstOrNull?.label ?? l.more;
          }
        } else if (branch < m.tabs.length) {
          title = m.tabs[branch].label;
        }

        // System back on another tab (or the More list) goes to the first tab; only the first tab exits.
        final onFirst = selected == 0 || destinationCount < 2;
        return PopScope(
          canPop: onFirst,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) navigationShell.goBranch(0);
          },
          child: Scaffold(
          appBar: AppBar(
            leading: inMoreScreen
                ? BackButton(onPressed: () => context.go(moreLocation))
                : null,
            title: Text(title),
            actions: [account],
          ),
          body: branchExists ? navigationShell : const SizedBox.shrink(),
          // NavigationBar needs at least two destinations; one screen is shown on its own.
          bottomNavigationBar: destinationCount < 2 ? null : NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) {
              if (i < m.tabs.length) {
                navigationShell.goBranch(i, initialLocation: i == branch);
              } else {
                navigationShell.goBranch(moreBranchIndex, initialLocation: onMore);
              }
            },
            destinations: [
              for (final t in m.tabs)
                NavigationDestination(icon: Icon(menuIcon(t.item.iconCls)), label: t.label),
              if (hasMore) NavigationDestination(icon: const Icon(Icons.more_horiz), label: l.more),
            ],
          ),
          ),
        );
      },
    );
  }
}

void showAccountSheet(BuildContext context, WidgetRef ref) {
  final l = AppLocalizations.of(context);
  final s = ref.read(sessionProvider);
  final name = '${s.user?['name'] ?? ''}';
  final email = '${s.user?['email'] ?? ''}';
  final customer = s.info?.customerCode;
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(name),
            subtitle: email.isEmpty ? null : Text(email),
          ),
          if (customer != null)
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: Text(l.organization),
              subtitle: Text(customer),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () {
              Navigator.of(ctx).pop();
              ref.read(sessionProvider.notifier).signOut();
            },
          ),
        ],
      ),
    ),
  );
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}
