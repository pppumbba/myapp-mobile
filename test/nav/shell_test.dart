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

MenuEntry entry(int id, String name, [String? group]) =>
    MenuEntry(MetaParam(id: id, paramName: name, labelName: name, refMetaId: id), group);

void main() {
  testWidgets('shell shows tabs plus More and opens a More screen', (tester) async {
    final menu = MobileMenu(
      [entry(1, 'Orders'), entry(2, 'Items'), entry(3, 'Stock')],
      [entry(4, 'Reports', 'Finance'), entry(5, 'Ledger', 'Finance')],
    );
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(SignedIn.new),
      mobileMenuProvider.overrideWith((ref) async => menu),
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

    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Orders')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')), findsOneWidget);
    expect(find.text('M1'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('M4'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
