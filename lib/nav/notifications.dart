import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart' show noRetry;
import 'pill_bar.dart' show pillCyan, pillViolet;
import 'top_bar.dart';

/// One of the signed-in user's notifications (user_notifications).
class AppNotification {
  final int id;
  final String title;
  final String? body;
  final DateTime? createdAt;
  final bool read;
  AppNotification({required this.id, required this.title, this.body, this.createdAt, this.read = false});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        title: '${j['title'] ?? ''}',
        body: j['body'] as String?,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        read: j['read_at'] != null,
      );
}

class NotificationPage {
  final List<AppNotification> items;
  final int unread;
  NotificationPage(this.items, this.unread);
}

/// The latest 20 notifications and the unread count, fetched again every minute while signed in.
final notificationsProvider = FutureProvider<NotificationPage>(retry: noRetry, (ref) async {
  ref.watch(sessionProvider.select((s) => s.user?['id']));
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final r = await ref.read(apiClientProvider).get<dynamic>('/notifications');
  final data = r is Map ? r['data'] : null;
  return NotificationPage(
    [if (data is List) for (final e in data) if (e is Map) AppNotification.fromJson(e.cast<String, dynamic>())],
    r is Map && r['unread'] is num ? (r['unread'] as num).toInt() : 0,
  );
});

/// The bell in the top bar, with the unread count.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.unread ?? 0;
    return TopBarButton(
      tooltip: AppLocalizations.of(context).notifications,
      onPressed: () {
        ref.invalidate(notificationsProvider);
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const NotificationSheet(),
        );
      },
      child: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: pillCyan,
        textColor: const Color(0xFF0B1020),
        label: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontWeight: FontWeight.w700)),
        child: Icon(unread > 0 ? Icons.notifications_active_outlined : Icons.notifications_none, size: 22),
      ),
    );
  }
}

class NotificationSheet extends ConsumerWidget {
  const NotificationSheet({super.key});

  Future<void> _write(WidgetRef ref, String path) async {
    try {
      await ref.read(apiClientProvider).post<dynamic>(path, const {});
    } on ApiError {
      // The list just stays as it was; the next refresh shows the truth.
    }
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final page = ref.watch(notificationsProvider);
    final unread = page.value?.unread ?? 0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(children: [
            Expanded(child: Text(l.notifications, style: theme.textTheme.titleLarge)),
            if (unread > 0) TextButton(onPressed: () => _write(ref, '/notifications/read-all'), child: Text(l.markAllRead)),
          ]),
        ),
        Flexible(
          child: switch (page) {
            AsyncValue(:final value?) when value.items.isNotEmpty => ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: value.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (_, i) {
                  final n = value.items[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active_outlined,
                        color: n.read ? theme.colorScheme.onSurfaceVariant : pillViolet),
                    title: Text(n.title, style: n.read ? null : const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: n.body == null || n.body!.isEmpty ? null : Text(n.body!, maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: n.createdAt == null ? null : Text(_ago(n.createdAt!, l), style: theme.textTheme.bodySmall),
                    onTap: n.read ? null : () => _write(ref, '/notifications/${n.id}/read'),
                  );
                },
              ),
            AsyncValue(:final value?) when value.items.isEmpty => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.noNotifications, textAlign: TextAlign.center),
              ),
            AsyncValue(:final error?) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(error is ApiError ? error.message : l.somethingWrong, textAlign: TextAlign.center),
              ),
            _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          },
        ),
      ]),
    );
  }

  static String _ago(DateTime t, AppLocalizations l) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 30) return '${d.inDays}d';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
