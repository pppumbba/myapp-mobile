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

/// Picks which params fill which card slot. Only shown, non-widget params take part.
/// Pass 1 places params the builder put in a slot (`widget_position`); a second claimant of a
/// single slot goes to body, and placed body/footer params are never capped.
/// Pass 2 guesses the still-empty slots from the unplaced params (at most 3 guessed body fields).
CardSlots cardSlots(List<MetaParam> gridParams) {
  final shown = [
    for (final p in gridParams)
      if (p.isShow && p.dataType != 'widget') p,
  ];
  final s = CardSlots(body: [], footer: []);
  final placed = <MetaParam>{};

  for (final p in shown) {
    switch (p.widgetPosition) {
      case 'title':
        if (s.title == null) { s.title = p; } else { s.body.add(p); }
      case 'subtitle':
        if (s.subtitle == null) { s.subtitle = p; } else { s.body.add(p); }
      case 'badge':
        if (s.badge == null) { s.badge = p; } else { s.body.add(p); }
      case 'image':
        if (s.image == null) { s.image = p; } else { s.body.add(p); }
      case 'body':
        s.body.add(p);
      case 'footer':
        s.footer.add(p);
      default:
        continue;
    }
    placed.add(p);
  }

  final rest = [for (final p in shown) if (!placed.contains(p)) p];
  MetaParam? take(bool Function(MetaParam) test) {
    final i = rest.indexWhere(test);
    return i < 0 ? null : rest.removeAt(i);
  }

  s.title ??= take((p) => p.isLabel) ?? take((_) => true);
  s.subtitle ??= take((_) => true);
  s.badge ??= take((p) => p.renderType == 'status');
  s.body.addAll(rest.take(3));
  return s;
}

const _web = {
  'approved': 's', 'received': 's', 'done': 's', 'completed': 's',
  'submitted': 'w', 'sent': 'w', 'pending': 'w', 'partially received': 'w', 'enrolled': 'w',
  'ordered': 'b', 'in progress': 'b', 'published': 'b',
  'rejected': 'e', 'cancelled': 'e', 'dropped': 'e', 'blocked': 'e',
};

/// The web's status words keep their colour; any other option gets a stable colour by its
/// index, spread around the scheme's primary hue. Values that are not options are gray.
/// On a dark scheme every colour is a lighter shade, so the chip stays readable.
Color statusColor(String value, List<String> options, {ColorScheme? scheme}) {
  final key = value.toLowerCase();
  final dark = scheme?.brightness == Brightness.dark;
  switch (_web[key]) {
    case 's':
      return dark ? Colors.green.shade300 : Colors.green.shade700;
    case 'w':
      return dark ? Colors.amber.shade300 : Colors.amber.shade800;
    case 'b':
      return scheme?.primary ?? const Color(0xFF4F46E5);
    case 'e':
      return dark ? Colors.red.shade300 : Colors.red.shade700;
  }
  final i = options.indexWhere((o) => o.toLowerCase() == key);
  if (i < 0) return dark ? Colors.blueGrey.shade200 : Colors.blueGrey;
  final base = HSLColor.fromColor(scheme?.primary ?? const Color(0xFF4F46E5)).hue;
  final hue = (base + i * 360 / (options.length < 2 ? 2 : options.length)) % 360;
  return HSLColor.fromAHSL(1, hue, dark ? 0.8 : 0.55, dark ? 0.74 : 0.42).toColor();
}
