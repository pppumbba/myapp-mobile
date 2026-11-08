import '../api/models.dart';

/// A menu item. A top-level one is a section of the bottom bar; its [children] are the screens
/// shown as tabs across the top. A screen has no children.
class MenuEntry {
  final MetaParam item;
  final String? group;
  final List<MenuEntry> children;
  MenuEntry(this.item, this.group, [this.children = const []]);

  int get metaId => item.refMetaId!;
  String get label => item.label;

  /// What this entry opens: its child screens, or itself.
  List<MenuEntry> get screens => children.isEmpty ? [this] : children;
}

class MobileMenu {
  final List<MenuEntry> tabs;
  final List<MenuEntry> more;
  MobileMenu(this.tabs, this.more);

  /// Every screen, section by section.
  List<MenuEntry> get all => [for (final s in [...tabs, ...more]) ...s.screens];
}

/// Turns the app meta's menu tree into sections: each top-level item is one bottom-bar slot, holding
/// itself (when it opens a screen) and every screen below it, at any depth. Sections with no screen
/// the user may open are left out; past [maxTabs] the rest go to a More list.
/// Only visible items whose ref meta can be viewed and is supported become screens.
MobileMenu flattenMenu(
  List<MetaParam> appParams, {
  required bool Function(int metaId) canView,
  required bool Function(int metaId) supported,
  int maxTabs = 5,
}) {
  List<MetaParam> sorted(List<MetaParam> items) => [...items]..sort((a, b) {
      final c = a.orderNumber.compareTo(b.orderNumber);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  bool opens(MetaParam p) => p.refMetaId != null && canView(p.refMetaId!) && supported(p.refMetaId!);

  final sections = <MenuEntry>[];
  for (final top in sorted(appParams)) {
    if (!top.isShow) continue;
    final screens = <MenuEntry>[];
    void walk(List<MetaParam> items) {
      for (final p in sorted(items)) {
        if (!p.isShow) continue;
        if (opens(p)) screens.add(MenuEntry(p, top.label));
        walk(p.children);
      }
    }

    if (opens(top)) screens.add(MenuEntry(top, top.label));
    walk(top.children);
    if (screens.isEmpty) continue;
    // A section that is just its own screen needs no tabs.
    final alone = screens.length == 1 && identical(screens.single.item, top);
    sections.add(alone ? MenuEntry(top, null) : MenuEntry(top, null, screens));
  }
  if (sections.length <= maxTabs) return MobileMenu(sections, const []);
  return MobileMenu(sections.sublist(0, maxTabs - 1), sections.sublist(maxTabs - 1));
}

/// Every meta id the menu points at, hidden items excluded.
Set<int> menuRefIds(List<MetaParam> params) {
  final out = <int>{};
  void walk(List<MetaParam> items) {
    for (final p in items) {
      if (!p.isShow) continue;
      if (p.refMetaId != null) out.add(p.refMetaId!);
      walk(p.children);
    }
  }

  walk(params);
  return out;
}
