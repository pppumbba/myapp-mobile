import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart' show noRetry;
import 'pill_bar.dart' show pillViolet;
import '../chat/inbox.dart' show openInbox;
import '../widgets/drop_toast.dart';
import '../widgets/edge_fade.dart';
import '../widgets/skeleton.dart';

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
  ref.watch(sessionScopeProvider);
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final r = await ref.read(apiClientProvider).get<dynamic>('/notifications');
  final data = r is Map ? r['data'] : null;
  return NotificationPage(
    [if (data is List) for (final e in data) if (e is Map) AppNotification.fromJson(e.cast<String, dynamic>())],
    r is Map && r['unread'] is num ? (r['unread'] as num).toInt() : 0,
  );
});

/// The newest notification that arrived between two reads of the list: unread and newer than
/// anything [prev] held. Null on the first read, so old unread ones never pop up.
AppNotification? arrivedNotification(NotificationPage? prev, NotificationPage? next) {
  if (prev == null || next == null) return null;
  final seen = prev.items.fold<int>(0, (m, n) => n.id > m ? n.id : m);
  final fresh = [for (final n in next.items) if (!n.read && n.id > seen) n]..sort((a, b) => b.id.compareTo(a.id));
  return fresh.firstOrNull;
}

/// Drops a toast out of the top edge for each notification that arrives while signed in;
/// tapping it opens the list.
void listenForArrivals(BuildContext context, WidgetRef ref) {
  ref.listen(notificationsProvider, (prev, next) {
    final n = arrivedNotification(prev?.value, next.value);
    if (n == null || !context.mounted) return;
    showDropToast(
      context,
      title: n.title,
      body: n.body,
      time: AppLocalizations.of(context).justNow,
      onTap: () => openInbox(context, ref),
    );
  });
}

/// The Notifications tab of the inbox: the list, with Mark all read over it while any are unread.
class NotificationList extends ConsumerWidget {
  const NotificationList({super.key});

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (unread > 0)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: () => _write(ref, '/notifications/read-all'), child: Text(l.markAllRead)),
          ),
        ),
      Expanded(
        child: switch (page) {
          AsyncValue(:final value?) when value.items.isNotEmpty => ListView.separated(
              padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
              itemCount: value.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (_, i) {
                final n = value.items[i];
                return EdgeFade(child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active_outlined,
                      color: n.read ? theme.colorScheme.onSurfaceVariant : pillViolet),
                  title: Text(n.title, style: n.read ? null : const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: n.body == null || n.body!.isEmpty ? null : Text(n.body!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: n.createdAt == null ? null : Text(_ago(n.createdAt!, l), style: theme.textTheme.bodySmall),
                  onTap: n.read ? null : () => _write(ref, '/notifications/${n.id}/read'),
                ));
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
          _ => const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), child: Shimmer(child: RowGroupSkeleton(rows: 4))),
        },
      ),
    ]);
  }

  static String _ago(DateTime t, AppLocalizations l) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 30) return '${d.inDays}d';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
