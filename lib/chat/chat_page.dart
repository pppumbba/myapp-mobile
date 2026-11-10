import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../form/values.dart' show primaryKey;
import '../grid/grid_screen.dart';
import '../l10n/app_localizations.dart';
import '../meta/defs.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;
import '../widgets/pull_refresh.dart' show RefreshRing;
import '../widgets/row_group.dart';
import '../widgets/skeleton.dart';
import '../widgets/drop_toast.dart';
import 'chat_api.dart';
import 'chat_widgets.dart';
import 'inbox.dart' show ChatAvatar, chatTime, openChat;

/// How often the open chat asks for news (the list itself is read every [chatListEvery]).
const chatPollEvery = Duration(seconds: 3);

/// One chat, full screen: messages in bubbles, newest at the bottom, and a box to write in.
class ChatPage extends ConsumerStatefulWidget {
  final ChatSummary chat;
  const ChatPage({super.key, required this.chat});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

/// How long a sent message takes to lift out of the box and land as a bubble.
const _flightSecs = 1.0;

/// The landing spring: 0 → 1, overshooting about 8%.
double _lift(double t) => springAt(t - 0.02, 14, 0.62);

class _ChatPageState extends ConsumerState<ChatPage> with TickerProviderStateMixin {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _field = GlobalKey();
  final _target = GlobalKey();
  List<ChatMessage> _messages = [];
  Map<int, int> _read = {};
  List<String> _typing = [];
  bool _loading = true, _more = false, _loadingOlder = false;
  Object? _error;
  Timer? _timer;
  DateTime _typedAt = DateTime(2000);
  late final ChatApi _api = ref.read(chatApiProvider);
  late final OpenChatId _open = ref.read(openChatIdProvider.notifier);

  // Sending: a message shows at once under a local (negative) id until the server answers; its
  // words fly from the box to where its bubble lands ([_flyer] over the page, the bubble itself
  // hidden and growing in the list, pushing the older ones up).
  int _nextLocal = -1;
  int? _flightId;
  OverlayEntry? _flyer;
  late final AnimationController _flight =
      AnimationController(vsync: this, duration: Duration(milliseconds: (_flightSecs * 1000).round()));

  /// The newest message the server has (local ones not counted).
  int get _last => _messages.fold(0, (a, m) => m.id > a ? m.id : a);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeOlder);
    Future.microtask(() => _open.set(widget.chat.id));
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flyer?.remove();
    _flight.dispose();
    _text.dispose();
    _scroll.dispose();
    // After the frame: providers can't change while the tree is being torn down.
    final id = widget.chat.id;
    Future.microtask(() => _open.clear(id));
    super.dispose();
  }

  Future<void> _poll() async {
    _timer?.cancel();
    try {
      final (list, open) = await _api.poll(open: widget.chat.id, after: _last);
      if (!mounted) return;
      if (open != null) {
        setState(() {
          if (_loading) _more = open.more;
          var list = _messages;
          for (final m in open.messages) {
            if (list.any((x) => x.id == m.id)) continue;
            // My own message, back before its send call answered: it takes the local one's place.
            final local = list.where((x) => x.id < 0 && x.userId == m.userId && x.body == m.body).firstOrNull;
            list = local != null ? _settled(list, local.id, m) : [...list, m];
          }
          _messages = list;
          _read = open.read;
          _typing = open.typing;
          _loading = false;
          _error = null;
        });
        final unread = list.chats.where((c) => c.id == widget.chat.id).firstOrNull?.unread ?? 0;
        if (unread > 0 && _last > 0) {
          unawaited(_api.read(widget.chat.id, _last).catchError((_) {}).then((_) => ref.invalidate(chatListProvider)));
        }
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
    if (mounted) _timer = Timer(chatPollEvery, _poll);
  }

  /// Near the top (the list runs bottom-up, so the far end), loads the page before.
  Future<void> _maybeOlder() async {
    if (!_more || _loadingOlder || _messages.isEmpty) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 300) return;
    setState(() => _loadingOlder = true);
    try {
      final (older, more) = await _api.older(widget.chat.id, _messages.first.id);
      if (!mounted) return;
      setState(() {
        _messages = [...older, ..._messages];
        _more = more;
      });
    } on ApiError {
      // Stays as it was; scrolling up again tries again.
    }
    if (mounted) setState(() => _loadingOlder = false);
  }

  void _typed(String _) {
    final now = DateTime.now();
    if (now.difference(_typedAt).inSeconds < 3) return;
    _typedAt = now;
    unawaited(_api.typing(widget.chat.id).catchError((_) {}));
  }

  /// [list] with the local message [localId] replaced by the server's [real] one (or dropped,
  /// when [real] is already there); a flight in progress follows it.
  List<ChatMessage> _settled(List<ChatMessage> list, int localId, ChatMessage real) {
    if (_flightId == localId) _flightId = real.id;
    final has = list.any((x) => x.id == real.id);
    return [for (final x in list) if (x.id != localId) x else if (!has) real];
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    final user = ref.read(sessionProvider).user;
    final local = ChatMessage(
      id: _nextLocal--,
      chatId: widget.chat.id,
      userId: (user?['id'] as num?)?.toInt(),
      userName: user?['name'] as String?,
      body: body,
      createdAt: DateTime.now(),
    );
    final from = _liftPoint();
    _text.clear();
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
    setState(() => _messages = [..._messages, local]);
    _fly(local, from);
    try {
      final m = await _api.send(widget.chat.id, body);
      if (!mounted) return;
      setState(() => _messages = _settled(_messages, local.id, m));
      ref.invalidate(chatListProvider);
    } on ApiError {
      if (!mounted) return;
      if (_flightId == local.id) _land();
      setState(() => _messages = [for (final x in _messages) if (x.id != local.id) x]);
      if (_text.text.isEmpty) _text.text = body; // back in the box, to try again
      showDropToast(context, title: AppLocalizations.of(context).sendFailed, icon: Icons.error_outline_rounded);
    }
  }

  /// Where the bubble's top-left sits as it lifts: over the words in the box (null when
  /// animations are off).
  Offset? _liftPoint() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return null;
    final box = _field.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    // The box's text inset (18, 12) less the bubble's (12, 8).
    return box.localToGlobal(const Offset(6, 4));
  }

  void _fly(ChatMessage m, Offset? from) {
    _land();
    if (from == null) return;
    _flightId = m.id;
    final ink = Theme.of(context).colorScheme.onSurface;
    _flyer = OverlayEntry(builder: (_) => _Flyer(clock: _flight, from: from, target: _target, message: m, ink: ink));
    Overlay.of(context).insert(_flyer!);
    _flight.forward(from: 0).whenComplete(_land);
  }

  /// Ends a flight: the bubble in the list shows, the flying one goes.
  void _land() {
    _flight.stop();
    _flyer?.remove();
    _flyer = null;
    if (_flightId != null && mounted) setState(() => _flightId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = (ref.watch(sessionProvider).user?['id'] as num?)?.toInt();
    final chat = widget.chat;
    // The last of my messages that every other member has read up to.
    final seenUpTo = _read.isEmpty ? 0 : _read.values.reduce((a, b) => a < b ? a : b);
    final mine = [for (final m in _messages) if (m.userId == me && m.id > 0) m.id];
    final seenId = mine.lastWhere((id) => id <= seenUpTo, orElse: () => 0);
    // My newest message, once the server has it and while it isn't seen yet.
    final deliveredId = mine.isNotEmpty && mine.last > seenId ? mine.last : 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Row(children: [
          ChatAvatar(name: chat.name, group: chat.isGroup, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              if (_typing.isNotEmpty)
                Text('${_typing.join(', ')} ${l.typingNow}', style: theme.textTheme.bodySmall?.copyWith(color: pillCyan))
              else if (chat.isGroup)
                Text(chat.members.map((m) => m.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: switch ((_loading, _error)) {
            (true, _) => const Padding(padding: EdgeInsets.all(16), child: Shimmer(child: RowGroupSkeleton(rows: 5, icons: false))),
            (_, final Object e) when _messages.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(e is ApiError ? e.message : l.somethingWrong, textAlign: TextAlign.center),
                ),
              ),
            _ => ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _messages.length) return const Padding(padding: EdgeInsets.only(bottom: 8), child: Shimmer(child: RowGroupSkeleton(rows: 1, icons: false)));
                  final m = _messages[_messages.length - 1 - i];
                  final prev = i + 1 < _messages.length ? _messages[_messages.length - 2 - i] : null;
                  final flying = m.id == _flightId;
                  final bubble = _Bubble(
                    message: m,
                    mine: m.userId == me,
                    showName: chat.isGroup && m.userId != me && prev?.userId != m.userId,
                    status: m.id == seenId ? l.seen : m.id == deliveredId ? l.delivered : null,
                    bodyKey: flying ? _target : null,
                  );
                  if (!flying) return bubble;
                  // Hidden while its words fly in; it grows, pushing the older messages up.
                  return AnimatedBuilder(
                    animation: _flight,
                    builder: (_, child) => ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: (1.15 * _lift(_flight.value * _flightSecs)).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                    child: Opacity(opacity: 0, child: bubble),
                  );
                },
              ),
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: _flight,
                  builder: (_, _) => TextField(
                    key: _field,
                    controller: _text,
                    // The bubbles' type, so the words don't change as they lift out.
                    style: theme.textTheme.bodyMedium,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _typed,
                    cursorColor: pillCyan,
                    cursorWidth: 2.5,
                    decoration: composerDecoration(
                      context,
                      hint: l.messageHint,
                      // Comes back only once the sent words have lifted clear.
                      hintStyle: TextStyle(
                        color: (theme.brightness == Brightness.dark ? const Color(0xFF6D6B88) : theme.colorScheme.onSurfaceVariant)
                            .withValues(alpha: _flightId == null ? 1 : ((_flight.value * _flightSecs - 0.08) / 0.15).clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ListenableBuilder(
                listenable: _text,
                builder: (_, _) => GlowButton(
                  tooltip: l.send,
                  onPressed: _text.text.trim().isEmpty ? null : _send,
                  child: const SendArrow(size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showName;
  /// Seen or Delivered, under my newest messages.
  final String? status;
  /// On the bubble itself, for a flight to land on.
  final Key? bodyKey;
  const _Bubble({required this.message, required this.mine, required this.showName, this.status, this.bodyKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = message;
    if (m.kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(m.body, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: showName ? 10 : 3, bottom: status != null ? 2 : 0),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Text(m.userName ?? '', style: theme.textTheme.labelSmall?.copyWith(color: pillCyan)),
          ),
        _BubbleBody(key: bodyKey, message: m, mine: mine),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4),
            child: Text(status!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

/// The bubble: its fill, the words and the time. [fill] fades the fill and time in (a flight's
/// start); [ink] is the words' colour in place of the usual.
class _BubbleBody extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final double fill;
  final Color? ink;
  const _BubbleBody({super.key, required this.message, required this.mine, this.fill = 1, this.ink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = message;
    final time = m.createdAt == null ? '' : chatTime(m.createdAt!, locale: Localizations.localeOf(context).languageCode);
    final fg = ink ?? (mine ? Colors.white : theme.colorScheme.onSurface);
    final words = theme.textTheme.bodyMedium?.copyWith(color: fg);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(colors: [pillViolet.withValues(alpha: fill), const Color(0xFF5A8BFF).withValues(alpha: fill)])
              : null,
          color: mine ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: fill),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (m.kind == 'record') SharedRecordCard(data: m.data ?? const {}, mine: mine),
            if (m.body.isNotEmpty) ...[
              if (m.kind == 'record') const SizedBox(height: 6),
              if (ink == null) SelectableText(m.body, style: words) else Text(m.body, style: words),
            ],
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(time, style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.65 * fill))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A sent message on its way: its words lift out of the box where they were typed, the bubble's
/// fill fades in under them, and it springs to where its bubble lands in the list ([target]).
class _Flyer extends StatelessWidget {
  final Animation<double> clock;
  final Offset from;
  final GlobalKey target;
  final ChatMessage message;
  /// The words' colour in the box.
  final Color ink;
  const _Flyer({required this.clock, required this.from, required this.target, required this.message, required this.ink});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final t = clock.value * _flightSecs;
          final fill = (t / 0.14).clamp(0.0, 1.0);
          final stage = Overlay.of(context).context.findRenderObject();
          final landing = target.currentContext?.findRenderObject();
          final to = landing is RenderBox && landing.attached && landing.hasSize ? landing.localToGlobal(Offset.zero) : from;
          var at = Offset.lerp(from, to, _lift(t))!;
          if (stage is RenderBox && stage.hasSize) at = stage.globalToLocal(at);
          return Stack(children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              child: Material(
                type: MaterialType.transparency,
                child: _BubbleBody(message: message, mine: true, fill: fill, ink: Color.lerp(ink, Colors.white, fill)),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// A grid row shared from the web: its title and the values the sender saw. Tapping it opens the
/// grid on that row.
class SharedRecordCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool mine;
  const SharedRecordCard({super.key, required this.data, required this.mine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = mine ? Colors.white : theme.colorScheme.onSurface;
    final fields = [
      if (data['fields'] is List)
        for (final f in data['fields'] as List)
          if (f is Map) ('${f['label'] ?? ''}', '${f['value'] ?? ''}'),
    ];
    final metaId = (data['meta_id'] as num?)?.toInt();
    final recordId = '${data['record_id'] ?? ''}';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: metaId == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SharedRecordPage(metaId: metaId, recordId: recordId, title: '${data['title'] ?? ''}'),
              )),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: mine ? Colors.white70 : pillViolet, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.table_rows_outlined, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(child: Text('${data['title'] ?? ''}', style: theme.textTheme.titleSmall?.copyWith(color: fg))),
          ]),
          for (final (label, value) in fields)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$label  ', style: TextStyle(color: fg.withValues(alpha: 0.65))),
                  TextSpan(text: value, style: TextStyle(color: fg)),
                ]),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ]),
      ),
    );
  }
}

/// The grid a shared record came from, filtered to that row by the grid's key.
class SharedRecordPage extends ConsumerWidget {
  final int metaId;
  final String recordId;
  final String title;
  const SharedRecordPage({super.key, required this.metaId, required this.recordId, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (ref.watch(metaDefProvider(metaId))) {
        AsyncValue(:final value?) => GridScreen(metaId: metaId, filters: {primaryKey(value.params): recordId}),
        AsyncValue(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(error is ApiError ? error.message : l.somethingWrong, textAlign: TextAlign.center),
            ),
          ),
        _ => const Shimmer(child: CardListSkeleton()),
      },
    );
  }
}

/// Pick someone to write to: opens (or starts) the direct chat with them.
class NewChatPage extends ConsumerStatefulWidget {
  const NewChatPage({super.key});

  @override
  ConsumerState<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends ConsumerState<NewChatPage> {
  final _query = TextEditingController();
  List<({int id, String name, String email})>? _people;
  String _shownFor = '';
  Object? _error;
  Timer? _debounce;
  int _round = 0;
  bool _searching = false;
  int? _opening;

  @override
  void initState() {
    super.initState();
    _find('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _debounce?.cancel();
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _find(q.trim()));
  }

  Future<void> _find(String q) async {
    final round = ++_round;
    try {
      final people = await ref.read(chatApiProvider).people(q);
      if (mounted && round == _round) {
        setState(() {
          _people = people;
          _shownFor = q;
          _error = null;
          _searching = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted && round == _round) {
        setState(() {
          _error = e;
          _searching = false;
        });
      }
    }
  }

  Future<void> _start(int userId) async {
    if (_opening != null) return;
    setState(() => _opening = userId);
    try {
      final chat = await ref.read(chatApiProvider).direct(userId);
      ref.invalidate(chatListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      openChat(context, chat);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _opening = null);
        showDropToast(context, title: e.message, icon: Icons.error_outline_rounded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final people = _people;
    final Widget results;
    if (_error != null && people == null) {
      results = Center(child: Text(_error is ApiError ? (_error as ApiError).message : l.somethingWrong));
    } else if (people == null) {
      results = const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Shimmer(child: RowGroupSkeleton(rows: 6)));
    } else if (people.isEmpty) {
      results = Padding(
        key: ValueKey('none:$_shownFor'),
        padding: const EdgeInsets.all(32),
        child: Text(_shownFor.isEmpty ? l.noPeople : l.noPeopleFound(_shownFor), textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    } else {
      results = ListView(
        key: ValueKey('list:$_shownFor'),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          RowGroup(indent: 64, children: [
            for (final (i, p) in people.indexed)
              _Rise(
                delay: Duration(milliseconds: 22 * (i < 10 ? i : 10)),
                child: InkWell(
                  onTap: _opening == null ? () => _start(p.id) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      ChatAvatar(name: p.name, size: 38),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text.rich(_marked(p.name, _shownFor, theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text.rich(_marked(p.email, _shownFor, theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      if (_opening == p.id)
                        const SizedBox.square(dimension: 22, child: RefreshRing(size: 22))
                      else
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                    ]),
                  ),
                ),
              ),
          ]),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.newChat)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ListenableBuilder(
            listenable: _query,
            builder: (_, _) => TextField(
              controller: _query,
              autofocus: true,
              style: theme.textTheme.bodyMedium,
              cursorColor: pillCyan,
              cursorWidth: 2.5,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              decoration: composerDecoration(context, hint: l.findPeople, prefixIcon: const Icon(Icons.search, size: 20)).copyWith(
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _query.clear();
                          _changed('');
                        },
                      ),
              ),
            ),
          ),
        ),
        // A thin violet→cyan line runs under the box while a search is out.
        SizedBox(
          height: 3,
          // Built only while searching: it never stops moving, even unseen.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _searching
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      child: LinearProgressIndicator(minHeight: 3, color: pillCyan, backgroundColor: Color(0x406E5BFF)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: results,
          ),
        ),
      ]),
    );
  }

  /// [text] with the part matching [query] in cyan (case ignored).
  static TextSpan _marked(String text, String query, TextStyle style) {
    final at = query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    if (at < 0) return TextSpan(text: text, style: style);
    return TextSpan(style: style, children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(text: text.substring(at, at + query.length), style: const TextStyle(color: pillCyan, fontWeight: FontWeight.w700)),
      TextSpan(text: text.substring(at + query.length)),
    ]);
  }
}

/// Fades in and rises 8 px into place after [delay]: search results arriving one after another.
class _Rise extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _Rise({required this.delay, required this.child});

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _wait = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _c.value = 1;
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final k = Curves.easeOutCubic.transform(_c.value);
          return Opacity(opacity: k, child: Transform.translate(offset: Offset(0, 8 * (1 - k)), child: child));
        },
        child: widget.child,
      );
}
