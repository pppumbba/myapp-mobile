import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/chat/chat_api.dart';
import 'package:wand_mobile/chat/chat_page.dart';
import 'package:wand_mobile/chat/inbox.dart';
import 'package:wand_mobile/chat/share_record.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';
import 'package:wand_mobile/nav/notifications.dart';

class SignedIn extends SessionController {
  @override
  SessionState build() => SessionState(
        info: MobileInfo(id: 5, name: 'Shop', customerCode: 'acme'),
        user: const {'id': 1, 'name': 'Bat', 'email': 'b@x.mn'},
        access: Access(isAdmin: true),
      );
}

ChatMessage msg(int id, int user, String body, {int chat = 7}) =>
    ChatMessage(id: id, chatId: chat, userId: user, userName: user == 1 ? 'Bat' : 'Saraa', body: body, createdAt: DateTime(2026, 11, 10, 9, id));

/// Answers the chat calls from memory and notes what was sent and read.
class FakeChatApi implements ChatApi {
  List<ChatMessage> messages;
  Map<int, int> readMarks;
  int unread;
  final sent = <String>[];
  final shared = <(int, String, String)>[]; // chat, record title, note
  bool fail = false;
  final reads = <int>[];
  FakeChatApi(this.messages, {this.readMarks = const {}, this.unread = 0});

  @override
  Future<(ChatList, OpenChat?)> poll({required int open, int after = 0}) async => (
        ChatList([ChatSummary(id: open, type: 'direct', name: 'Saraa', unread: unread)], unread),
        OpenChat([for (final m in messages) if (m.id > after) m], false, const [], readMarks),
      );

  @override
  Future<ChatMessage> send(int chatId, String body) async {
    if (fail) throw ApiError(500, 'down');
    sent.add(body);
    final m = msg(messages.length + 100, 1, body);
    messages = [...messages, m];
    return m;
  }

  @override
  Future<void> read(int chatId, int messageId) async {
    reads.add(messageId);
    unread = 0;
  }

  @override
  Future<void> typing(int chatId) async {}

  @override
  Future<ChatMessage> shareRecord(int chatId, Map<String, dynamic> record, {String note = ''}) async {
    shared.add((chatId, '${record['title']}', note));
    return ChatMessage(id: 500, chatId: chatId, userId: 1, kind: 'record', body: note, data: record);
  }

  @override
  Future<ChatSummary> direct(int userId) async => ChatSummary(id: 40 + userId, type: 'direct', name: 'Person $userId');

  final everyone = const [
    (id: 2, name: 'Saraa Bold', email: 'saraa@x.mn'),
    (id: 3, name: 'Enkh Bat', email: 'enkh@x.mn'),
  ];

  @override
  Future<List<({int id, String name, String email})>> people(String q) async =>
      [for (final p in everyone) if ('${p.name} ${p.email}'.toLowerCase().contains(q.toLowerCase())) p];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(Widget home, List overrides) => ProviderScope(
      overrides: [sessionProvider.overrideWith(SignedIn.new), ...overrides.cast()],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  group('arrivedChatMessage', () {
    ChatList list(int lastId, int from, {int unread = 1}) =>
        ChatList([ChatSummary(id: 7, type: 'direct', name: 'Saraa', last: msg(lastId, from, 'hi'), unread: unread)], unread);

    test('nothing on the first read, so old unread messages never pop up', () {
      expect(arrivedChatMessage(null, list(5, 2)), isNull);
    });

    test('a newer message from someone else arrives', () {
      final hit = arrivedChatMessage(list(5, 2), list(6, 2), me: 1);
      expect(hit?.$2.id, 6);
    });

    test('not my own message, nor one in the chat on screen, nor one already read', () {
      expect(arrivedChatMessage(list(5, 2), list(6, 1, unread: 0), me: 1), isNull);
      expect(arrivedChatMessage(list(5, 2), list(6, 2), me: 1, openId: 7), isNull);
      expect(arrivedChatMessage(list(5, 2), list(6, 2, unread: 0), me: 1), isNull);
    });
  });

  test('chatTime: the clock today, the date long ago', () {
    final now = DateTime(2026, 11, 10, 18);
    expect(chatTime(DateTime(2026, 11, 10, 9, 5), now: now), '09:05');
    expect(chatTime(DateTime(2026, 10, 1, 9, 5), now: now), '2026-10-01');
  });

  testWidgets('a chat shows its messages, marks them read, sends, and says Seen under mine', (tester) async {
    final api = FakeChatApi([msg(1, 2, 'Hello'), msg(2, 1, 'Hi Saraa')], readMarks: {2: 2}, unread: 1);
    await tester.pumpWidget(app(
      const ChatPage(chat: ChatSummary(id: 7, type: 'direct', name: 'Saraa')),
      [chatApiProvider.overrideWithValue(api), chatListProvider.overrideWith((ref) async => const ChatList([], 0))],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hi Saraa'), findsOneWidget);
    expect(find.text('Seen'), findsOneWidget);
    expect(api.reads, [2]);

    await tester.enterText(find.byType(TextField), '  See you at 3  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty, reason: 'the words leave the box at once');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('See you at 3'), findsNWidgets(2), reason: 'in flight, over its hidden bubble in the list');
    await tester.pumpAndSettle();
    expect(api.sent, ['See you at 3']);
    expect(find.text('See you at 3'), findsOneWidget, reason: 'landed');
    expect(find.text('Seen'), findsOneWidget, reason: 'still under the read one');
    expect(find.text('Delivered'), findsOneWidget, reason: 'under the new one');
    await tester.pumpWidget(const SizedBox()); // stops the poll timer
    await tester.pump();
  });

  testWidgets('a send that fails takes the message back out and puts the words back in the box', (tester) async {
    final api = FakeChatApi([msg(1, 2, 'Hello')])..fail = true;
    await tester.pumpWidget(app(
      const ChatPage(chat: ChatSummary(id: 7, type: 'direct', name: 'Saraa')),
      [chatApiProvider.overrideWithValue(api), chatListProvider.overrideWith((ref) async => const ChatList([], 0))],
    ));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Lost?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Could not send. Try again.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Lost?');
    expect(find.descendant(of: find.byType(ListView), matching: find.text('Lost?')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the inbox holds notifications and chats under two tabs with their counts', (tester) async {
    await tester.pumpWidget(app(
      const Scaffold(body: InboxSheet()),
      [
        notificationsProvider.overrideWith((ref) async => NotificationPage([AppNotification(id: 1, title: 'PO approved')], 1)),
        chatListProvider.overrideWith((ref) async => ChatList([ChatSummary(id: 7, type: 'direct', name: 'Saraa', last: msg(3, 2, 'Are you in?'), unread: 2)], 2)),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notifications (1)'), findsOneWidget);
    expect(find.text('Chats (2)'), findsOneWidget);
    expect(find.text('PO approved'), findsOneWidget);
    await tester.tap(find.text('Chats (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Saraa'), findsOneWidget);
    expect(find.text('Saraa: Are you in?'), findsNothing, reason: 'a direct chat needs no name before the line');
    expect(find.text('Are you in?'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);
  });

  testWidgets('new chat: everyone at first, narrowed as you type, a word for no match', (tester) async {
    await tester.pumpWidget(app(const NewChatPage(), [chatApiProvider.overrideWithValue(FakeChatApi(const []))]));
    await tester.pumpAndSettle();
    expect(find.text('Saraa Bold', findRichText: true), findsOneWidget);
    expect(find.text('Enkh Bat', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sar');
    await tester.pumpAndSettle();
    expect(find.text('Saraa Bold', findRichText: true), findsOneWidget);
    expect(find.text('Enkh Bat', findRichText: true), findsNothing);
    expect(find.byTooltip('Clear'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No one matches “zzz”.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Enkh Bat', findRichText: true), findsOneWidget);
  });

  testWidgets('share a row: the card shows, a note goes with it, a chat or a new person receives it', (tester) async {
    final api = FakeChatApi(const []);
    const record = {'meta_id': 131, 'record_id': '7', 'title': 'Work orders · WO-7', 'fields': [{'label': 'Status', 'value': 'Open'}]};
    await tester.pumpWidget(app(
      Builder(builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShareRecordPage(record: record))),
                child: const Text('go'),
              ),
            ),
          )),
      [
        chatApiProvider.overrideWithValue(api),
        chatListProvider.overrideWith((ref) async => const ChatList([
              ChatSummary(id: 7, type: 'direct', name: 'Saraa Bold', members: [(id: 1, name: 'Bat'), (id: 2, name: 'Saraa Bold')]),
            ], 0)),
      ],
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Work orders · WO-7'), findsOneWidget);
    expect(find.text('Saraa Bold'), findsOneWidget, reason: 'once, as the chat; not again under People');
    expect(find.text('Enkh Bat'), findsOneWidget, reason: 'no chat with Enkh yet: under People');

    await tester.enterText(find.byType(TextField).first, 'Can you check this?');
    await tester.tap(find.text('Enkh Bat'));
    await tester.pump();
    await tester.pump();
    expect(api.shared, [(43, 'Work orders · WO-7', 'Can you check this?')]);
    await tester.pump(const Duration(milliseconds: 800)); // the drop falls and opens
    expect(find.text('Shared with Person 3'), findsOneWidget);
    expect(find.text('Work orders · WO-7'), findsOneWidget, reason: 'the record, under it in the toast');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('go'), findsOneWidget, reason: 'back where it was shared from');
    await tester.pumpAndSettle(); // the toast leaves
  });
}
