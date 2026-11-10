import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan;
import '../widgets/drop_toast.dart';
import '../widgets/pull_refresh.dart' show RefreshRing;
import '../widgets/row_group.dart';
import '../widgets/skeleton.dart';
import 'chat_api.dart';
import 'chat_page.dart' show SharedRecordCard;
import 'chat_widgets.dart';
import 'inbox.dart' show ChatAvatar, openChat;

/// Sends a grid row to a chat as a card: pick one of your chats, or a person (that starts the
/// direct chat with them), with an optional note. [record] is the card,
/// {meta_id, record_id, title, fields: [{label, value}]}.
class ShareRecordPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> record;
  const ShareRecordPage({super.key, required this.record});

  @override
  ConsumerState<ShareRecordPage> createState() => _ShareRecordPageState();
}

class _ShareRecordPageState extends ConsumerState<ShareRecordPage> {
  final _note = TextEditingController();
  final _query = TextEditingController();
  List<({int id, String name, String email})> _people = const [];
  Timer? _debounce;
  int _round = 0;
  String? _sendingTo;

  @override
  void initState() {
    super.initState();
    _findPeople('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _note.dispose();
    _query.dispose();
    super.dispose();
  }

  void _changed(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _findPeople(q.trim()));
  }

  Future<void> _findPeople(String q) async {
    final round = ++_round;
    try {
      final people = await ref.read(chatApiProvider).people(q);
      if (mounted && round == _round) setState(() => _people = people);
    } on ApiError {
      // The chats still show; people come back with the next search.
    }
  }

  /// Sends to [chat], or first starts the direct chat with person [userId].
  Future<void> _share({ChatSummary? chat, int? userId, required String key}) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = key);
    final api = ref.read(chatApiProvider);
    try {
      final to = chat ?? await api.direct(userId!);
      await api.shareRecord(to.id, widget.record, note: _note.text.trim());
      ref.invalidate(chatListProvider);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      // The app's own drop toast (on the root overlay, so it stays as this page closes); tapping
      // it opens the chat it went to.
      showDropToast(
        context,
        title: l.sharedWith(to.name),
        body: '${widget.record['title'] ?? ''}',
        icon: Icons.check_rounded,
        onTap: () {
          if (rootContext.mounted) openChat(rootContext, to);
        },
      );
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      showDropToast(context, title: e.message, icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _query.text.trim().toLowerCase();
    final list = ref.watch(chatListProvider);
    final chats = [for (final c in list.value?.chats ?? const <ChatSummary>[]) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
    // People you already have a direct chat with show once, as that chat.
    final direct = {
      for (final c in list.value?.chats ?? const <ChatSummary>[])
        if (!c.isGroup)
          for (final m in c.members) m.id,
    };
    final people = [for (final p in _people) if (!direct.contains(p.id)) p];

    // The chat's glowing send button; while sending, the ring turns inside it.
    Widget trailing(String key, String to, VoidCallback onTap) => GlowButton(
          tooltip: '${l.send}: $to',
          size: 32,
          onPressed: _sendingTo == null ? onTap : null,
          child: _sendingTo == key ? const RefreshRing(size: 18, onGradient: true) : const SendArrow(size: 17),
        );
    Widget row({required Widget avatar, required String title, String? subtitle, required String key, required VoidCallback onTap}) =>
        InkWell(
          onTap: _sendingTo == null ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
              trailing(key, title, onTap),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.shareToChat)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          // What goes: the card as it will show in the chat.
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
              child: Padding(padding: const EdgeInsets.all(8), child: SharedRecordCard(data: widget.record, mine: false)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            style: theme.textTheme.bodyMedium,
            cursorColor: pillCyan,
            cursorWidth: 2.5,
            textCapitalization: TextCapitalization.sentences,
            decoration: composerDecoration(context, hint: l.addNote),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            style: theme.textTheme.bodyMedium,
            cursorColor: pillCyan,
            cursorWidth: 2.5,
            onChanged: _changed,
            decoration: composerDecoration(context, hint: l.findPeople, prefixIcon: const Icon(Icons.search, size: 20)),
          ),
          if (list.isLoading && list.value == null)
            const Padding(padding: EdgeInsets.only(top: 16), child: Shimmer(child: RowGroupSkeleton(rows: 4)))
          else ...[
            if (chats.isNotEmpty) ...[
              RowGroupHeading(l.chats),
              RowGroup(indent: 64, children: [
                for (final c in chats)
                  row(
                    avatar: ChatAvatar(name: c.name, group: c.isGroup, size: 38),
                    title: c.name,
                    subtitle: c.isGroup ? c.members.map((m) => m.name).join(', ') : null,
                    key: 'c${c.id}',
                    onTap: () => _share(chat: c, key: 'c${c.id}'),
                  ),
              ]),
            ],
            if (people.isNotEmpty) ...[
              RowGroupHeading(l.people),
              RowGroup(indent: 64, children: [
                for (final p in people)
                  row(
                    avatar: ChatAvatar(name: p.name, size: 38),
                    title: p.name,
                    subtitle: p.email,
                    key: 'p${p.id}',
                    onTap: () => _share(userId: p.id, key: 'p${p.id}'),
                  ),
              ]),
            ],
            if (chats.isEmpty && people.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(q.isEmpty ? l.noPeople : l.noPeopleFound(_query.text.trim()),
                    textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
          ],
        ],
      ),
    );
  }
}
