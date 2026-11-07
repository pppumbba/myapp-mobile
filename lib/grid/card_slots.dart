import 'package:flutter/material.dart';

import '../api/models.dart';

class CardSlots {
  MetaParam? title;
  MetaParam? subtitle;
  MetaParam? badge;
  MetaParam? image;
  List<MetaParam> body;
  List<MetaParam> footer;

  CardSlots({this.title, this.subtitle, this.badge, this.image, this.body = const [], this.footer = const []});
}

/// Picks which params fill which card slot. Only shown, non-widget params take part;
/// a slot named by `widget_position` wins over the automatic choice.
CardSlots cardSlots(List<MetaParam> gridParams) {
  final shown = [
    for (final p in gridParams)
      if (p.isShow && p.dataType != 'widget') p,
  ];
  final s = CardSlots(body: [], footer: []);
  final taken = <MetaParam>{};

  for (final p in shown) {
    switch (p.widgetPosition) {
      case 'title':
        s.title ??= p;
      case 'subtitle':
        s.subtitle ??= p;
      case 'badge':
        s.badge ??= p;
      case 'image':
        s.image ??= p;
      case 'body':
        s.body.add(p);
      case 'footer':
        s.footer.add(p);
      default:
        continue;
    }
    taken.add(p);
  }
  // A slot that was already filled by an earlier param leaves the later one unplaced.
  taken.removeWhere((p) => s.title != p && s.subtitle != p && s.badge != p && s.image != p && !s.body.contains(p) && !s.footer.contains(p));

  List<MetaParam> rest() => [
        for (final p in shown)
          if (!taken.contains(p) && p.widgetPosition != 'image') p,
      ];

  if (s.title == null) {
    final r = rest();
    final t = r.where((p) => p.isLabel).firstOrNull ?? r.firstOrNull;
    if (t != null) {
      s.title = t;
      taken.add(t);
    }
  }
  if (s.subtitle == null) {
    final t = rest().firstOrNull;
    if (t != null) {
      s.subtitle = t;
      taken.add(t);
    }
  }
  if (s.badge == null) {
    final t = rest().where((p) => p.renderType == 'status').firstOrNull;
    if (t != null) {
      s.badge = t;
      taken.add(t);
    }
  }
  for (final p in rest()) {
    if (s.body.length >= 3) break;
    s.body.add(p);
    taken.add(p);
  }
  return s;
}

/// A stable colour per option index, spread around the scheme's primary hue.
Color statusColor(String value, List<String> options, {ColorScheme? scheme}) {
  final i = options.indexWhere((o) => o.toLowerCase() == value.toLowerCase());
  if (i < 0) return Colors.blueGrey;
  final base = HSLColor.fromColor(scheme?.primary ?? const Color(0xFF4F46E5)).hue;
  final hue = (base + i * 360 / (options.length < 2 ? 2 : options.length)) % 360;
  return HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
}
