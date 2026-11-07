import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/app.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';
import 'package:wand_mobile/meta/defs.dart';
import 'package:wand_mobile/nav/menu.dart';
import 'package:wand_mobile/nav/shell.dart';

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
  MobileMenu menu,
) async {
  final holder = NotifierProvider<MenuHolder, MobileMenu>(() => MenuHolder(menu));
  final container = ProviderContainer(overrides: [
    sessionProvider.overrideWith(SignedIn.new),
    mobileMenuProvider.overrideWith((ref) async => ref.watch(holder)),
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
