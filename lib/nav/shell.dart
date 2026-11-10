import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../screens/screen_view.dart';
import '../widgets/inchworm_tabs.dart';
import '../widgets/skeleton.dart';
import '../widgets/row_group.dart';
import 'icons.dart';
import '../chat/inbox.dart' show InboxBell, listenForChats;
import 'notifications.dart';
import 'pill_bar.dart';
import 'scroll_chrome.dart';
import 'top_bar.dart';
import 'menu.dart';
import '../account/account.dart';
import '../widgets/error_state.dart';

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
    // The account page's rounded blocks: a section with screens under its heading; screens of
    // their own that follow each other share one block without a heading.
    final children = <Widget>[];
    var loose = <Widget>[];
    void flushLoose() {
      if (loose.isEmpty) return;
      children.add(Padding(padding: const EdgeInsets.only(top: 16), child: RowGroup(children: loose)));
      loose = [];
    }

    for (final section in menu.more) {
      final rows = [
        for (final e in section.screens)
          IconRow(
            icon: menuIcon(e.item.iconCls ?? section.item.iconCls),
            title: e.label,
            onTap: () => context.go('$moreLocation/screen/${e.metaId}'),
          ),
      ];
      if (section.children.isEmpty) {
        loose.addAll(rows);
        continue;
      }
      flushLoose();
      children
        ..add(RowGroupHeading(section.label))
        ..add(RowGroup(children: rows));
    }
    flushLoose();
    // An explicit padding drops ListView's own safe-area padding, so the tab bar's height is added back.
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: children,
    );
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
    listenForChats(context, ref);
    final account = AccountAvatar(name: userName, tooltip: l.account, onPressed: () => showAccountSheet(context));
    // The app's name and mark stay out of the app: the bar holds only the user's tools.
    PreferredSizeWidget bar({Widget? leading, Widget? search}) => AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          centerTitle: false,
          title: Row(children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(child: search ?? const SizedBox.shrink()),
            const SizedBox(width: 10),
            if (search != null) ...[const InboxBell(), const SizedBox(width: 10)],
            account,
          ]),
        );

    // A reload (another language or customer) keeps the old menu up until the new one is in, so
    // the tab navigators and any page pushed over them stay put.
    return menu.when(
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        appBar: bar(),
        // The first screen's cards, as every other load shows.
        body: const CardListSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: bar(),
        body: ErrorState.of(context, e, onRetry: () {
          ref.invalidate(metaDefProvider);
          ref.invalidate(metaTypeProvider);
          ref.invalidate(mobileMenuProvider);
        }),
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
        titleSpacing: 0,
        centerTitle: false,
        // The top bar's pill, now typed into: it keeps its look.
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: MenuSearchField(hint: l.searchMenus, onChanged: (v) => setState(() => _q = v)),
        ),
      ),
      body: hits.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.noMenuMatch)))
          // Hits under their section's heading, in the account page's rounded blocks.
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              for (final section in {for (final (s, _) in hits) s}) ...[
                RowGroupHeading(section.label),
                RowGroup(children: [
                  for (final (s, e) in hits)
                    if (identical(s, section))
                      IconRow(
                        icon: menuIcon(e.item.iconCls ?? section.item.iconCls),
                        title: e.label,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onPick(section, e);
                        },
                      ),
                ]),
              ],
            ]),
    );
  }
}
