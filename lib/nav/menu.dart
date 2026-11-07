import '../api/models.dart';

class MenuEntry {
  final MetaParam item;
  final String? group;
  MenuEntry(this.item, this.group);

  int get metaId => item.refMetaId!;
  String get label => item.label;
}

class MobileMenu {
  final List<MenuEntry> tabs;
  final List<MenuEntry> more;
  MobileMenu(this.tabs, this.more);

  List<MenuEntry> get all => [...tabs, ...more];
}

/// Flattens the app meta's menu tree into bottom tabs plus a More list.
/// Only visible items whose ref meta can be viewed and is supported become screens.
MobileMenu flattenMenu(
  List<MetaParam> appParams, {
  required bool Function(int metaId) canView,
  required bool Function(int metaId) supported,
  int maxTabs = 4,
}) {
  final screens = <MenuEntry>[];
  void walk(List<MetaParam> items, String? group) {
    final sorted = [...items]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    for (final p in sorted) {
      if (!p.isShow) continue;
      final ref = p.refMetaId;
      if (ref != null) {
        if (canView(ref) && supported(ref)) screens.add(MenuEntry(p, group));
        walk(p.children, group);
      } else {
        walk(p.children, p.label);
      }
    }
  }

  walk(appParams, null);
  if (screens.length <= maxTabs) return MobileMenu(screens, const []);
  return MobileMenu(screens.sublist(0, maxTabs - 1), screens.sublist(maxTabs - 1));
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
