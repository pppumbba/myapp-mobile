import 'package:flutter/material.dart';

/// Web `icon_cls` keys mapped to Material icons.
const menuIcons = <String, IconData>{
  'cart': Icons.shopping_cart_outlined,
  'plus': Icons.add_circle_outline,
  'file': Icons.description_outlined,
  'receipt': Icons.receipt_long_outlined,
  'database': Icons.storage_outlined,
  'folder': Icons.folder_outlined,
  'grid': Icons.grid_view_outlined,
  'home': Icons.home_outlined,
  'package': Icons.inventory_2_outlined,
  'chart': Icons.bar_chart_outlined,
  'calendar': Icons.calendar_month_outlined,
  'users': Icons.group_outlined,
  'truck': Icons.local_shipping_outlined,
  'search': Icons.search,
  'settings': Icons.settings_outlined,
  'tool': Icons.build_outlined,
  'zap': Icons.bolt_outlined,
};

const fallbackMenuIcon = Icons.widgets_outlined;

IconData menuIcon(String? key) => menuIcons[key] ?? fallbackMenuIcon;
