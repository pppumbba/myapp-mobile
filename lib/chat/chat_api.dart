import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../meta/defs.dart' show noRetry;

/// One message of a chat (chat_messages). [kind] is text, system, or record: a grid row shared as
/// a card, its [data] {meta_id, record_id, title, fields: [{label, value}]}.
class ChatMessage {
  final int id;
  final int chatId;
  final int? userId;
  final String? userName;
  final String kind;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;
  const ChatMessage({
    required this.id,
    required this.chatId,
    this.userId,
    this.userName,
    this.kind = 'text',
    this.body = '',
    this.data,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        chatId: (j['chat_id'] as num).toInt(),
        userId: (j['user_id'] as num?)?.toInt(),
        userName: j['user_name'] as String?,
        kind: '${j['kind'] ?? 'text'}',
        body: '${j['body'] ?? ''}',
        data: j['data'] is Map ? (j['data'] as Map).cast<String, dynamic>() : null,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      );

  /// A shared record's title, or null for other kinds.
  String? get recordTitle => kind == 'record' ? '${data?['title'] ?? ''}' : null;

  /// The line a chat list shows for it.
  String get preview => kind == 'record' ? [recordTitle, if (body.isNotEmpty) body].join(' · ') : body;
}

/// One chat as the list shows it: a direct chat is named after the other person.
class ChatSummary {
  final int id;
  final String type;
  final String name;
  final List<({int id, String name})> members;
  final ChatMessage? last;
  final int unread;
  final List<String> typing;
  const ChatSummary({
    required this.id,
    required this.type,
    required this.name,
    this.members = const [],
    this.last,
    this.unread = 0,
    this.typing = const [],
  });

  bool get isGroup => type == 'group';

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
        id: (j['id'] as num).toInt(),
        type: '${j['type'] ?? 'direct'}',
        name: '${j['name'] ?? ''}',
        members: [
          if (j['members'] is List)
            for (final m in j['members'] as List)
              if (m is Map) (id: (m['id'] as num).toInt(), name: '${m['name'] ?? ''}'),
        ],
        last: j['last'] is Map ? ChatMessage.fromJson((j['last'] as Map).cast<String, dynamic>()) : null,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        typing: [if (j['typing'] is List) for (final t in j['typing'] as List) '$t'],
      );
}

class ChatList {
  final List<ChatSummary> chats;
  final int unread;
  const ChatList(this.chats, this.unread);
}

/// The open chat's news since the last message shown: new messages, who is typing, and each
/// other member's read mark (user id -> last message id read).
class OpenChat {
  final List<ChatMessage> messages;
  final bool more;
  final List<String> typing;
  final Map<int, int> read;
  const OpenChat(this.messages, this.more, this.typing, this.read);

  factory OpenChat.fromJson(Map<String, dynamic> j) => OpenChat(
        [
          if (j['messages'] is List)
            for (final m in j['messages'] as List)
              if (m is Map) ChatMessage.fromJson(m.cast<String, dynamic>()),
        ],
        j['more'] == true,
        [if (j['typing'] is List) for (final t in j['typing'] as List) '$t'],
        {
          if (j['read'] is Map)
            for (final e in (j['read'] as Map).entries) int.parse('${e.key}'): (e.value as num).toInt(),
        },
      );
}

/// How often the chat list is read again while signed in (there is no push on the phone yet).
const chatListEvery = Duration(seconds: 15);

/// The user's chats and their unread total, read again every [chatListEvery].
final chatListProvider = FutureProvider<ChatList>(retry: noRetry, (ref) async {
  ref.watch(sessionScopeProvider);
  final timer = Timer(chatListEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final r = await ref.read(apiClientProvider).get<dynamic>('/chats/poll');
  return ChatList(
    [
      if (r is Map && r['chats'] is List)
        for (final c in r['chats'] as List)
          if (c is Map) ChatSummary.fromJson(c.cast<String, dynamic>()),
    ],
    r is Map && r['unread'] is num ? (r['unread'] as num).toInt() : 0,
  );
});

/// The chat on screen, so its arrivals don't pop up as toasts.
final openChatIdProvider = NotifierProvider<OpenChatId, int?>(OpenChatId.new);

class OpenChatId extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int id) => state = id;

  /// Clears it, unless another chat opened since (a toast tapped from inside a chat).
  void clear(int id) {
    if (ref.mounted && state == id) state = null;
  }
}

/// The chat calls the screens make, on the signed-in user's client.
class ChatApi {
  final ApiClient _client;
  ChatApi(this._client);

  /// The list and, for [open], its messages after [after] (the last page when 0).
  Future<(ChatList, OpenChat?)> poll({required int open, int after = 0}) async {
    final r = await _client.get<dynamic>('/chats/poll', query: {'open': open, 'after': after});
    final list = ChatList(
      [
        if (r is Map && r['chats'] is List)
          for (final c in r['chats'] as List)
            if (c is Map) ChatSummary.fromJson(c.cast<String, dynamic>()),
      ],
      r is Map && r['unread'] is num ? (r['unread'] as num).toInt() : 0,
    );
    final o = r is Map && r['open'] is Map ? OpenChat.fromJson((r['open'] as Map).cast<String, dynamic>()) : null;
    return (list, o);
  }

  /// The page of messages before [before], oldest first, and whether there are more.
  Future<(List<ChatMessage>, bool)> older(int chatId, int before) async {
    final r = await _client.get<dynamic>('/chats/$chatId/messages', query: {'before': before});
    return (
      [
        if (r is Map && r['messages'] is List)
          for (final m in r['messages'] as List)
            if (m is Map) ChatMessage.fromJson(m.cast<String, dynamic>()),
      ],
      r is Map && r['more'] == true,
    );
  }

  Future<ChatMessage> send(int chatId, String body) async =>
      ChatMessage.fromJson(Map<String, dynamic>.from(await _client.post<dynamic>('/chats/$chatId/messages', {'body': body}) as Map));


  /// Shares a grid row as a card ({meta_id, record_id, title, fields: [{label, value}]}), with an
  /// optional note under it.
  Future<ChatMessage> shareRecord(int chatId, Map<String, dynamic> record, {String note = ''}) async => ChatMessage.fromJson(
      Map<String, dynamic>.from(await _client.post<dynamic>('/chats/$chatId/messages', {'body': note, 'record': record}) as Map));
  Future<void> read(int chatId, int messageId) => _client.post<dynamic>('/chats/$chatId/read', {'message_id': messageId});

  Future<void> typing(int chatId) => _client.post<dynamic>('/chats/$chatId/typing', const {});

  /// People to start a chat with, by name or email.
  Future<List<({int id, String name, String email})>> people(String q) async {
    final r = await _client.get<dynamic>('/chats/people', query: {'q': q});
    return [
      if (r is List)
        for (final p in r)
          if (p is Map) (id: (p['id'] as num).toInt(), name: '${p['name'] ?? ''}', email: '${p['email'] ?? ''}'),
    ];
  }

  /// The direct chat with [userId], made if there is none yet.
  Future<ChatSummary> direct(int userId) async =>
      ChatSummary.fromJson(Map<String, dynamic>.from(await _client.post<dynamic>('/chats/direct', {'user_id': userId}) as Map));
}

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi(ref.watch(apiClientProvider)));
