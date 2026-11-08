import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/app.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/form/form_screen.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';
import 'package:wand_mobile/meta/defs.dart';
import 'package:wand_mobile/nav/menu.dart';
import 'package:wand_mobile/nav/shell.dart';
import 'package:wand_mobile/stage_query/stage_query_sheet.dart';

class SignedIn extends SessionController {
  @override
  SessionState build() => SessionState(
        info: MobileInfo(id: 5, name: 'Shop', customerCode: 'acme'),
        user: const {'id': 1, 'name': 'Bat', 'email': 'b@x.mn'},
        access: Access(isAdmin: true),
      );
}

class MenuHolder extends Notifier<MobileMenu> {
  MenuHolder(this.initial);
  final MobileMenu initial;
  @override
  MobileMenu build() => initial;
  void set(MobileMenu m) => state = m;
}

MenuEntry entry(int id, String name, [String? group]) =>
    MenuEntry(MetaParam(id: id, paramName: name, labelName: name, refMetaId: id), group);

Future<(ProviderContainer, NotifierProvider<MenuHolder, MobileMenu>)> pumpShell(
  WidgetTester tester,
  MobileMenu menu, {
  bool menuFails = false,
  List<Override> extra = const [],
}
) async {
  final holder = NotifierProvider<MenuHolder, MobileMenu>(() => MenuHolder(menu));
  final container = ProviderContainer(overrides: [
    sessionProvider.overrideWith(SignedIn.new),
    mobileMenuProvider.overrideWith((ref) async {
      if (menuFails) throw ApiError(0, defaultUnreachableMessage);
      return ref.watch(holder);
    }),
    ...extra,
    for (final id in [1, 2, 3, 4, 5])
      metaDefProvider(id).overrideWith((ref) async => MetaDef(Meta(id: id, name: 'M$id', type: 'dashboard'), const [])),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: container.read(routerProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    ),
  ));
  container.read(routerProvider).go('/t/0');
  await tester.pumpAndSettle();
  return (container, holder);
}

Finder inBar(String text) => find.descendant(of: find.byType(NavigationBar), matching: find.text(text));

void main() {
  pushedPageTests();
  testWidgets('3 tabs plus More: opens a More screen with back button', (tester) async {
    await pumpShell(
      tester,
      MobileMenu(
        [entry(1, 'Orders'), entry(2, 'Items'), entry(3, 'Stock')],
        [entry(4, 'Reports', 'Finance'), entry(5, 'Ledger', 'Finance')],
      ),
    );
    expect(inBar('Orders'), findsOneWidget);
    expect(inBar('More'), findsOneWidget);
    expect(find.text('M1'), findsOneWidget);

    await tester.tap(inBar('More'));
    await tester.pumpAndSettle();
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('M4'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('one screen: no NavigationBar, no crash', (tester) async {
    await pumpShell(tester, MobileMenu([entry(1, 'Orders')], const []));
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('M1'), findsOneWidget);
  });

  testWidgets('two screens: NavigationBar with two destinations and no More', (tester) async {
    await pumpShell(tester, MobileMenu([entry(1, 'Orders'), entry(2, 'Items')], const []));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(inBar('Orders'), findsOneWidget);
    expect(inBar('Items'), findsOneWidget);
    expect(inBar('More'), findsNothing);
  });

  testWidgets('no screens: shows the nothing-to-show message', (tester) async {
    await pumpShell(tester, MobileMenu(const [], const []));
    expect(find.text('There is nothing to show in this app yet.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('More disappearing while on /more returns to the first tab', (tester) async {
    final (c, holder) = await pumpShell(
      tester,
      MobileMenu([entry(1, 'Orders'), entry(2, 'Items'), entry(3, 'Stock')], [entry(4, 'Reports')]),
    );
    await tester.tap(inBar('More'));
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsWidgets);

    c.read(holder.notifier).set(MobileMenu([entry(1, 'Orders'), entry(2, 'Items'), entry(3, 'Stock')], const []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('M1'), findsOneWidget);
    expect(inBar('More'), findsNothing);
  });

  testWidgets('a fourth tab disappearing while on it returns to the first tab', (tester) async {
    final (c, holder) = await pumpShell(
      tester,
      MobileMenu([entry(1, 'A'), entry(2, 'B'), entry(3, 'C'), entry(4, 'D')], const []),
    );
    await tester.tap(inBar('D'));
    await tester.pumpAndSettle();
    expect(find.text('M4'), findsOneWidget);

    c.read(holder.notifier).set(MobileMenu([entry(1, 'A'), entry(2, 'B'), entry(3, 'C')], const []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('M1'), findsOneWidget);
  });
}

void pushedPageTests() {
  testWidgets('system back on another tab goes to the first tab; a More screen goes back to More', (tester) async {
    await pumpShell(
      tester,
      MobileMenu([entry(1, 'Orders'), entry(2, 'Items')], [entry(4, 'Reports', 'Finance')]),
    );
    await tester.tap(inBar('Items'));
    await tester.pumpAndSettle();
    expect(find.text('M2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('M1'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);

    await tester.tap(inBar('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('M4'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Finance'), findsOneWidget, reason: 'back from a More screen shows the More list');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('M1'), findsOneWidget);
  });


  testWidgets('a form opened from a tab covers the shell: no NavigationBar, one app bar', (tester) async {
    await pumpShell(
      tester,
      MobileMenu([entry(1, 'Orders'), entry(2, 'Items')], const []),
      extra: [
        metaDefProvider(9).overrideWith((ref) async => MetaDef(
              Meta(id: 9, name: 'Order form', type: 'form'),
              [MetaParam(id: 1, paramName: 'title', labelName: 'Title', dataType: 'string', isShow: true)],
            )),
      ],
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    bool? result;
    openForm(tester.element(find.text('M1')), formMetaId: 9).then((r) => result = r);
    await tester.pumpAndSettle();
    expect(find.text('Order form'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a sheet opened from a tab sits above the NavigationBar (root navigator)', (tester) async {
    await pumpShell(
      tester,
      MobileMenu([entry(1, 'Orders'), entry(2, 'Items')], const []),
      extra: [
        metaDefProvider(9).overrideWith((ref) async => MetaDef(
              Meta(id: 9, name: 'Complete', type: 'stage_query'),
              [MetaParam(id: 1, paramName: 'work_order_id', fieldPath: 'work_order_id', labelName: 'Work order', dataType: 'integer', isShow: true)],
            )),
      ],
    );
    final tab = tester.element(find.text('M1'));
    runStageQuery(tab, stageQueryMetaId: 9, params: const {});
    await tester.pumpAndSettle();
    final inSheet = tester.element(find.text('Work order'));
    expect(Navigator.of(inSheet), same(Navigator.of(tab, rootNavigator: true)));
  });

  testWidgets('an offline menu load shows the unreachable message and Retry', (tester) async {
    await pumpShell(tester, MobileMenu([entry(1, 'Orders')], const []), menuFails: true);
    expect(find.text(defaultUnreachableMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
