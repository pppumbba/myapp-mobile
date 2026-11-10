import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../nav/notifications.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import '../nav/top_bar.dart';
import '../widgets/drop_toast.dart';
import '../widgets/edge_fade.dart';
import '../widgets/inchworm_tabs.dart';
import '../widgets/skeleton.dart';
import '../widgets/snap_sheet.dart';
import 'chat_api.dart';
import 'chat_page.dart';
import 'chat_widgets.dart';

/// Refreshes notifications and chats and opens the inbox on [tab] (0 notifications, 1 chats).
void openInbox(BuildContext context, WidgetRef ref, {int tab = 0}) {
  ref.invalidate(notificationsProvider);
  ref.invalidate(chatListProvider);
  showSnapSheet<void>(context, initial: SnapHeight.half, builder: (_) => InboxSheet(tab: tab));
}

/// Opens one chat over everything, the inbox's sheet or not.
void openChat(BuildContext context, ChatSummary chat) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => ChatPage(chat: chat)));

/// The newest chat message that came in between two reads of the list, from someone else, in a
/// chat other than [openId]. Null on the first read, so old unread ones never pop up.
(ChatSummary, ChatMessage)? arrivedChatMessage(ChatList? prev, ChatList? next, {int? me, int? openId}) {
  if (prev == null || next == null) return null;
  final before = {for (final c in prev.chats) c.id: c.last?.id ?? 0};
  for (final c in next.chats) {
    final m = c.last;
    if (m == null || c.id == openId || c.unread == 0 || m.kind == 'system' || m.userId == me) continue;
    if (m.id > (before[c.id] ?? 0)) return (c, m);
  }
  return null;
}

/// Drops a toast for each chat message that arrives while signed in (not for the chat on
/// screen); tapping it opens that chat.
void listenForChats(BuildContext context, WidgetRef ref) {
  ref.listen(chatListProvider, (prev, next) {
    final me = (ref.read(sessionProvider).user?['id'] as num?)?.toInt();
    final hit = arrivedChatMessage(prev?.value, next.value, me: me, openId: ref.read(openChatIdProvider));
    if (hit == null || !context.mounted) return;
    final (chat, m) = hit;
    showDropToast(
      context,
      title: chat.isGroup ? '${chat.name} · ${m.userName ?? ''}' : chat.name,
      body: m.preview,
      time: AppLocalizations.of(context).justNow,
      onTap: () => openChat(context, chat),
    );
  });
}

/// The bell in the top bar: unread notifications and chat messages together.
class InboxBell extends ConsumerWidget {
  const InboxBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notificationsProvider).value?.unread ?? 0;
    final chats = ref.watch(chatListProvider).value?.unread ?? 0;
    final unread = notes + chats;
    return TopBarButton(
      tooltip: AppLocalizations.of(context).inbox,
      // Straight to the chats when only they have news.
      onPressed: () => openInbox(context, ref, tab: chats > 0 && notes == 0 ? 1 : 0),
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

/// Notifications and chats in one sheet, under two tabs with their unread counts.
class InboxSheet extends ConsumerStatefulWidget {
  final int tab;
  const InboxSheet({super.key, this.tab = 0});

  @override
  ConsumerState<InboxSheet> createState() => _InboxSheetState();
}

class _InboxSheetState extends ConsumerState<InboxSheet> {
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final notes = ref.watch(notificationsProvider).value?.unread ?? 0;
    final chats = ref.watch(chatListProvider).value?.unread ?? 0;
    String label(String name, int n) => n > 0 ? '$name ($n)' : name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
        child: Row(children: [
          Expanded(child: Text(l.inbox, style: Theme.of(context).textTheme.titleLarge)),
          if (_tab == 1)
            GlowButton(
              tooltip: l.newChat,
              size: 34,
              onPressed: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute<void>(builder: (_) => const NewChatPage())),
              child: const Icon(Icons.edit_rounded),
            ),
        ]),
      ),
      InchwormTabBar(
        labels: [label(l.notifications, notes), label(l.chats, chats)],
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
      Expanded(
        child: SpringPages(
          index: _tab,
          count: 2,
          builder: (_, i) => i == 0 ? const NotificationList() : const ChatListView(),
        ),
      ),
    ]);
  }
}

/// The Chats tab: the user's chats, latest first, with the last message and unread count.
class ChatListView extends ConsumerWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = (ref.watch(sessionProvider).user?['id'] as num?)?.toInt();
    return switch (ref.watch(chatListProvider)) {
      AsyncValue(:final value?) when value.chats.isEmpty => Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.noChats, textAlign: TextAlign.center),
        ),
      AsyncValue(:final value?) => ListView.separated(
          padding: EdgeInsets.only(top: 4, bottom: 16 + MediaQuery.paddingOf(context).bottom),
          itemCount: value.chats.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, endIndent: 20),
          itemBuilder: (_, i) {
            final c = value.chats[i];
            final m = c.last;
            final line = c.typing.isNotEmpty
                ? '${c.typing.join(', ')} ${l.typingNow}'
                : m == null
                    ? ''
                    : [if (m.userId == me) l.you else if (c.isGroup && m.userName != null) m.userName!, m.preview].join(': ');
            return EdgeFade(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: ChatAvatar(name: c.name, group: c.isGroup),
                title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: c.unread > 0 ? const TextStyle(fontWeight: FontWeight.w700) : null),
                subtitle: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: c.typing.isNotEmpty ? const TextStyle(color: pillCyan) : null),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (m?.createdAt != null) Text(chatTime(m!.createdAt!, locale: Localizations.localeOf(context).languageCode), style: theme.textTheme.bodySmall),
                  if (c.unread > 0) ...[
                    const SizedBox(height: 4),
                    Badge(
                      backgroundColor: pillViolet,
                      label: Text(c.unread > 99 ? '99+' : '${c.unread}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                onTap: () => openChat(context, c),
              ),
            );
          },
        ),
      AsyncValue(:final error?) => Padding(
          padding: const EdgeInsets.all(32),
          child: Text(error is ApiError ? error.message : l.somethingWrong, textAlign: TextAlign.center),
        ),
      _ => const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), child: Shimmer(child: RowGroupSkeleton(rows: 4))),
    };
  }
}

/// A round mark with the chat's initial, or a group icon.
class ChatAvatar extends StatelessWidget {
  final String name;
  final bool group;
  final double size;
  const ChatAvatar({super.key, required this.name, this.group = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().characters.firstOrNull?.toUpperCase() ?? '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [pillViolet, pillCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: group
          ? Icon(Icons.group_outlined, color: Colors.white, size: size * 0.5)
          : Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42)),
    );
  }
}

/// 14:05 today, the weekday (in [locale]) this week, else 2026-11-03.
String chatTime(DateTime t, {DateTime? now, String locale = 'en'}) {
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final day = DateTime(t.year, t.month, t.day), today = DateTime(n.year, n.month, n.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${two(t.hour)}:${two(t.minute)}';
  if (days < 7) return DateFormat.E(locale).format(t);
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}
