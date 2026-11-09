import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';
import 'package:wand_mobile/widgets/violet_date_picker.dart';

void main() {
  Future<Future<DateTime?>> open(WidgetTester tester, {DateTime? initial, DateTime? first, DateTime? last}) async {
    late Future<DateTime?> result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => result = showVioletDatePicker(
                context,
                initial: initial,
                first: first ?? DateTime(1900),
                last: last ?? DateTime(2100),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows the month Monday first; a tapped day is spelled out and Apply returns it', (tester) async {
    final result = await open(tester, initial: DateTime(2026, 2, 10));
    expect(find.text('February'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    // 1 February 2026 is a Sunday, so the first row starts on Monday 26 January.
    final firstCell = tester.getTopLeft(find.bySemanticsLabel('Monday, January 26, 2026'));
    final sunday = tester.getTopLeft(find.bySemanticsLabel('Sunday, February 1, 2026'));
    expect(sunday.dy, firstCell.dy, reason: 'same week row');
    expect(sunday.dx, greaterThan(firstCell.dx));

    await tester.tap(find.bySemanticsLabel('Friday, February 20, 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Friday, February 20'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2026, 2, 20));
  });

  testWidgets('arrows and sideways swipes change month; Cancel returns null', (tester) async {
    final result = await open(tester, initial: DateTime(2026, 2, 10));
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('March'), findsOneWidget);

    await tester.fling(find.bySemanticsLabel('Wednesday, March 11, 2026'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('February'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('tapping a grey day of the next month moves there', (tester) async {
    await open(tester, initial: DateTime(2026, 2, 10));
    await tester.tap(find.bySemanticsLabel('Sunday, March 1, 2026'));
    await tester.pumpAndSettle();
    expect(find.text('March'), findsOneWidget);
    expect(find.text('Sunday, March 1'), findsOneWidget);
  });

  testWidgets('Today jumps to today and then turns off', (tester) async {
    final now = DateUtils.dateOnly(DateTime.now());
    await open(tester, initial: DateTime(now.year - 1, 1, 15));
    expect(find.textContaining('days ago'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Today'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· Today'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Today')).onPressed, isNull);
  });

  testWidgets('days and months outside the range cannot be picked', (tester) async {
    final result = await open(tester, initial: DateTime(2026, 2, 10), first: DateTime(2026, 2, 5), last: DateTime(2026, 2, 25));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded)).onPressed, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded)).onPressed, isNull);
    await tester.tap(find.bySemanticsLabel('Wednesday, February 4, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2026, 2, 10), reason: 'the 4th is before the first day allowed');
  });
}
