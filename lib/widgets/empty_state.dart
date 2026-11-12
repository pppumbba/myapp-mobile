import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'error_state.dart' show GlowDisc;
import 'pill_buttons.dart';

/// A list with nothing to show, in the error state's style: the violet → cyan disc, a title and a
/// line under it, and [action] as a soft pill. [EmptyState.noMatches] when a search or filter
/// hides everything (with a way to clear them), [EmptyState.nothingYet] when there are no records.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final ({String label, IconData? icon, VoidCallback onPressed})? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  factory EmptyState.noMatches(BuildContext context, {VoidCallback? onClear}) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: l.noResults,
      message: l.noMatchesHint,
      action: onClear == null ? null : (label: l.clearSearch, icon: Icons.close_rounded, onPressed: onClear),
    );
  }

  /// [canAdd]: the screen has its + button, so the line points to it.
  factory EmptyState.nothingYet(BuildContext context, {bool canAdd = false}) {
    final l = AppLocalizations.of(context);
    return EmptyState(icon: Icons.inbox_rounded, title: l.nothingYet, message: canAdd ? l.nothingYetAdd : l.nothingYetHint);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GlowDisc(icon: icon),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: SoftButton(
                  onPressed: action.onPressed,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (action.icon != null) ...[Icon(action.icon, size: 18), const SizedBox(width: 8)],
                    Flexible(child: Text(action.label, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
