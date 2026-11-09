import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';
import 'package:wand_mobile/meta/defs.dart';
import 'package:wand_mobile/screens/tabs_screen.dart';
import 'package:wand_mobile/widgets/inchworm_tabs.dart';

class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
        user: const {'id': 1},
        access: Access.fromJson(const {'is_admin': false, 'metas': {'2': {'view': true}, '3': {'view': true}}}),
      );
}

void main() {
  testWidgets('tabs show their screens in a strip, named after the screens, leaving out ones the user may not see', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        for (final (id, name) in [(2, 'Locations'), (3, 'Categories'), (4, 'Secret')])
          metaDefProvider(id).overrideWith((ref) async => MetaDef(Meta(id: id, name: name, type: 'report'), const [])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TabsScreen(
            meta: Meta(id: 1, name: 'Setup', type: 'tabs'),
            params: [
              MetaParam(id: 10, paramName: 'a', refMetaId: 2, orderNumber: 1),
              MetaParam(id: 11, paramName: 'b', refMetaId: 3, orderNumber: 2),
              MetaParam(id: 12, paramName: 'c', refMetaId: 4, orderNumber: 3),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final strip = find.byType(InchwormTabBar);
    expect(find.descendant(of: strip, matching: find.text('Locations')), findsOneWidget);
    expect(find.descendant(of: strip, matching: find.text('Categories')), findsOneWidget);
    expect(find.text('Secret'), findsNothing);

    await tester.tap(find.descendant(of: strip, matching: find.text('Categories')));
    await tester.pumpAndSettle();
    // The unsupported stand-in screen shows its name.
    expect(find.text('Categories'), findsNWidgets(2));
  });
}
