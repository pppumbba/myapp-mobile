import 'package:flutter/material.dart';

import '../api/client.dart' show ApiError;
import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import 'pill_buttons.dart';

/// The gradient disc with a white icon, in a faint halo of its own colour (error and empty states).
class GlowDisc extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  const GlowDisc({super.key, required this.icon, this.colors = const [pillViolet, pillCyan]});

  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        height: 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.first.withValues(alpha: 0.1)),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 6))],
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      );
}

/// A page or list that couldn't load, in the app's style: a glowing disc (violet → cyan with a
/// cloud when the server can't be reached, pink → coral "!" for any other error, like the error
/// banner), a title, the message, and Retry as the gradient pill. [secondary] goes under it as a
/// soft pill (Sign out on the splash); [top] above the disc (the app's mark).
class ErrorState extends StatelessWidget {
  final String message;
  final bool offline;
  final VoidCallback? onRetry;
  final ({String label, VoidCallback onPressed})? secondary;
  final Widget? top;
  const ErrorState({super.key, required this.message, this.offline = false, this.onRetry, this.secondary, this.top});

  /// From a load's error: offline when nothing answered (an ApiError with status 0).
  factory ErrorState.of(BuildContext context, Object error, {VoidCallback? onRetry, Widget? top}) => ErrorState(
        message: error is ApiError ? error.message : AppLocalizations.of(context).somethingWrong,
        offline: error is ApiError && error.status == 0,
        onRetry: onRetry,
        top: top,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = offline ? const [pillViolet, pillCyan] : const [pillPink, pillCoral];
    final secondary = this.secondary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (top != null) ...[top!, const SizedBox(height: 36)],
            GlowDisc(icon: offline ? Icons.cloud_off_rounded : Icons.priority_high_rounded, colors: colors),
            const SizedBox(height: 22),
            Text(offline ? l.noConnection : l.couldNotLoad,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: GradientButton(
                  onPressed: onRetry,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.refresh_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(l.retry),
                  ]),
                ),
              ),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 10),
              SizedBox(width: 220, child: SoftButton(onPressed: secondary.onPressed, child: Text(secondary.label))),
            ],
          ]),
        ),
      ),
    );
  }
}
