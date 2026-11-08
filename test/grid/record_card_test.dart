import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/grid/card_slots.dart';
import 'package:wand_mobile/grid/record_card.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('RecordCard with 40-char values does not overflow at 360 px width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final long = 'x' * 40;
    MetaParam mk(int i, String n, {String? render}) => MetaParam(id: i, paramName: n, labelName: 'Label $n $long', renderType: render);
    final slots = CardSlots(
      title: mk(1, 't'),
      subtitle: mk(2, 's'),
      badge: mk(3, 'b', render: 'status'),
      body: [mk(4, 'a'), mk(5, 'c')],
      footer: [mk(6, 'f')],
    );
    final row = {for (final k in ['t', 's', 'b', 'a', 'c', 'f']) k: long};
    var more = 0, tap = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RecordCard(slots: slots, row: row, onTap: () => tap++, onMore: () => more++)),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(InkWell).first);
    await tester.longPress(find.byType(InkWell).first);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(tap, 1);
    expect(more, 1);
  });

  testWidgets('RecordCard image slot renders for a URL and not for a file value', (tester) async {
    final img = MetaParam(id: 1, paramName: 'pic', labelName: 'Pic');
    final title = MetaParam(id: 2, paramName: 't', labelName: 'T');
    Future<void> pump(Object? value) => tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RecordCard(slots: CardSlots(title: title, image: img), row: {'t': 'x', 'pic': value})),
        ));
    await pump('https://example.com/a.png');
    expect(find.byType(Image), findsOneWidget);
    await pump('[{"id":3,"name":"a.png"}]');
    expect(find.byType(Image), findsNothing);
    await pump([{'id': 3}]);
    expect(find.byType(Image), findsNothing);
  });
}
