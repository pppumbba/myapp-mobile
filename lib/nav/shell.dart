import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../screens/screen_view.dart';
import '../widgets/inchworm_tabs.dart';
import 'icons.dart';
import 'notifications.dart';
import 'pill_bar.dart';
import 'scroll_chrome.dart';
import 'top_bar.dart';
import 'menu.dart';
import '../widgets/snap_sheet.dart';

const maxTabBranches = 5;

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

/// Which tab each section shows, by the section's menu item id.
class SectionTabs extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};
  void select(int sectionId, int tab) => state = {...state, sectionId: tab};
}

final sectionTabProvider = NotifierProvider<SectionTabs, Map<int, int>>(SectionTabs.new);

/// Root page of tab branch [index]: that section's screen, or its screens under a tab strip.
class TabRoot extends ConsumerWidget {
  final int index;
  const TabRoot(this.index, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(mobileMenuProvider).value;
    if (menu == null || index >= menu.tabs.length) return const SizedBox.shrink();
    final e = menu.tabs[index];
    if (e.children.isEmpty) return ScreenView(key: ValueKey(e.metaId), metaId: e.metaId);
    return SectionView(key: ValueKey(e.item.id), section: e);
  }
}

/// A section's screens: the inchworm strip across the top, the chosen screen below.
class SectionView extends ConsumerWidget {
  final MenuEntry section;
  const SectionView({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screens = section.screens;
    final index = (ref.watch(sectionTabProvider)[section.item.id] ?? 0).clamp(0, screens.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InchwormTabBar(
        labels: [for (final e in screens) e.label],
        index: index,
        onTap: (i) => ref.read(sectionTabProvider.notifier).select(section.item.id, i),
      ),
      Expanded(
        child: SpringPages(
          index: index,
          count: screens.length,
          builder: (_, i) => ScreenView(key: ValueKey(screens[i].metaId), metaId: screens[i].metaId),
        ),
      ),
    ]);
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
    for (final section in menu.more) {
      if (section.children.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(section.label, style: Theme.of(context).textTheme.labelLarge),
        ));
      }
      for (final e in section.screens) {
        children.add(ListTile(
          leading: Icon(menuIcon(e.item.iconCls ?? section.item.iconCls)),
          title: Text(e.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('$moreLocation/screen/${e.metaId}'),
        ));
      }
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
    final userName = ref.watch(sessionProvider.select((s) => '${s.user?['name'] ?? ''}'));
    listenForArrivals(context, ref);
    final account = AccountAvatar(name: userName, tooltip: l.account, onPressed: () => showAccountSheet(context, ref));
    // The app's name and mark stay out of the app: the bar holds only the user's tools.
    PreferredSizeWidget bar({Widget? leading, Widget? search}) => AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(child: search ?? const SizedBox.shrink()),
            const SizedBox(width: 10),
            if (search != null) ...[const NotificationBell(), const SizedBox(width: 10)],
            account,
          ]),
        );

    return menu.when(
      loading: () => Scaffold(
        appBar: bar(),
        body: const _MenuSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: bar(),
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
            appBar: bar(),
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

        final segs = routeState.uri.pathSegments;
        final inMoreScreen = onMore && segs.length >= 3 && segs[1] == 'screen';

        // A screen picked in the menu search: its section's slot, then its tab (or the More list's entry).
        void open(MenuEntry section, MenuEntry screen) {
          final i = m.tabs.indexOf(section);
          if (i < 0) return context.go('$moreLocation/screen/${screen.metaId}');
          if (section.children.isNotEmpty) {
            ref.read(sectionTabProvider.notifier).select(section.item.id, section.screens.indexOf(screen));
          }
          navigationShell.goBranch(i);
        }

        // System back on another tab (or the More list) goes to the first tab; only the first tab exits.
        final onFirst = selected == 0 || destinationCount < 2;
        return PopScope(
          canPop: onFirst,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) navigationShell.goBranch(0);
          },
          // Scrolling down folds the top bar away; scrolling up (or another tab) brings it back.
          child: ScrollChrome(
          resetKey: '$branch ${routeState.uri} ${ref.watch(sectionTabProvider)}',
          builder: (context, shown) => Scaffold(
          // Screens run on under the floating tab bar and show through it; they get its height
          // as bottom padding (MediaQuery), so the last record and the add button stay clear of it.
          extendBody: true,
          body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            CollapseOnScroll(shown: shown, child: MediaQuery.removePadding(context: context, removeTop: true, child: bar(
            leading: inMoreScreen
                ? TopBarButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.go(moreLocation),
                    child: const Icon(Icons.arrow_back, size: 22),
                  )
                : null,
            search: MenuSearchPill(
              hint: l.searchMenus,
              onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
                builder: (_) => MenuSearchPage(menu: m, onPick: open),
              )),
            ),
          ))),
            Expanded(
              // The Scaffold's own context, so the tab bar height it adds to the bottom padding is kept.
              child: Builder(
                builder: (context) => MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: branchExists ? navigationShell : const SizedBox.shrink(),
                ),
              ),
            ),
          ]),
          // The tab bar needs at least two destinations; one screen is shown on its own.
          bottomNavigationBar: destinationCount < 2 ? null : PillNavBar(
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
                PillDestination(icon: menuIcon(t.item.iconCls), label: t.label),
              if (hasMore) PillDestination(icon: Icons.more_horiz, label: l.more),
            ],
          ),
          )),
        );
      },
    );
  }
}

/// Searches the user's own menu: every screen they may open, by its name or its section's.
class MenuSearchPage extends StatefulWidget {
  final MobileMenu menu;
  final void Function(MenuEntry section, MenuEntry screen) onPick;
  const MenuSearchPage({super.key, required this.menu, required this.onPick});

  @override
  State<MenuSearchPage> createState() => _MenuSearchPageState();
}

class _MenuSearchPageState extends State<MenuSearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _q.trim().toLowerCase();
    final hits = [
      for (final section in [...widget.menu.tabs, ...widget.menu.more])
        for (final e in section.screens)
          if (q.isEmpty || e.label.toLowerCase().contains(q) || section.label.toLowerCase().contains(q)) (section, e),
    ];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l.searchMenus, border: InputBorder.none),
        ),
      ),
      body: hits.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.noMenuMatch)))
          : ListView(children: [
              for (final (section, e) in hits)
                ListTile(
                  leading: Icon(menuIcon(e.item.iconCls ?? section.item.iconCls)),
                  title: Text(e.label),
                  subtitle: identical(e.item, section.item) ? null : Text(section.label),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onPick(section, e);
                  },
                ),
            ]),
    );
  }
}

void showAccountSheet(BuildContext context, WidgetRef ref) {
  final l = AppLocalizations.of(context);
  final s = ref.read(sessionProvider);
  final name = '${s.user?['name'] ?? ''}';
  final email = '${s.user?['email'] ?? ''}';
  final customer = s.info?.customerCode;
  showSnapSheet<void>(
    context,
    initial: SnapHeight.peek,
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
