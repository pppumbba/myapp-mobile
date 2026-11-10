import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import 'pill_buttons.dart' show pillCoral, pillPink;


/// A form's error in the date picker's night style: a rounded row with a pink → coral "!" circle
/// (the destructive pill's colours) and the message beside it. [ErrorBanner.info] is the same row
/// in the main pill's violet → cyan, for news that isn't an error (a check's result).
class ErrorBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final List<Color> colors;
  const ErrorBanner({super.key, required this.message}) : icon = Icons.priority_high_rounded, colors = const [pillPink, pillCoral];
  const ErrorBanner.info({super.key, required this.message, this.icon = Icons.check_rounded}) : colors = const [pillViolet, pillCyan];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1C1B2B) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: colors.first.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.18), blurRadius: 18)],
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: dark ? const Color(0xFFC4C2E0) : const Color(0xFF3A3852), height: 1.3)),
          ),
        ]),
      ),
    );
  }
}
