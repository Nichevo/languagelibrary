import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  testWidgets('find a word, star it, then practise it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await tester.pumpWidget(appForTest(loadRealLibrary(), store));

    // Library: search for hello.
    await tester.enterText(find.byType(TextField), 'nihao');
    await tester.pumpAndSettle();
    expect(find.text('你好'), findsWidgets);

    // Open the entry card.
    await tester.tap(find.text('你好').first);
    await tester.pumpAndSettle();
    expect(find.text('Female voice'), findsOneWidget);
    expect(find.text('Male voice'), findsOneWidget);
    expect(find.textContaining('ní hǎo', findRichText: true), findsOneWidget); // tone change note

    // Star it from the entry card.
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.star_border)));
    await tester.pumpAndSettle();
    expect(store.starred.length, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Focus tab shows it with 2 due cards.
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 cards due'), findsOneWidget);

    // Practise: Chinese side first, reveal, rate Good.
    await tester.tap(find.textContaining('Study 2 due cards'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chinese → English'), findsOneWidget);
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(find.textContaining('English → Chinese'), findsOneWidget);
    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('All done: 2 cards'), findsOneWidget);
    expect(store.cards.length, 2);
  });

  testWidgets('related words: star one in place, open another', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final lib = loadRealLibrary();
    await tester.pumpWidget(appForTest(lib, store));

    await tester.enterText(find.byType(TextField), 'shu1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('书').first);
    await tester.pumpAndSettle();

    final heading = find.text('Related words and phrases');
    await tester.scrollUntilVisible(heading, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    final measure = find.text('Its measure word');
    await tester.scrollUntilVisible(measure, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();

    // Star the measure word 本 from inside the related list.
    final benCard = find.ancestor(of: measure, matching: find.byType(Card));
    final benStar = find.descendant(of: benCard, matching: find.byIcon(Icons.star_border));
    await tester.ensureVisible(benStar);
    await tester.pumpAndSettle();
    await tester.tap(benStar);
    await tester.pumpAndSettle();
    final ben = lib.entries.firstWhere((e) => e.simplified == '本' && e.pinyin == 'běn');
    expect(store.isStarred(ben.id), isTrue);

    // Tap it to open its own page.
    await tester.tap(measure);
    await tester.pumpAndSettle();
    expect(find.text('本'), findsWidgets);
    expect(find.text('Female voice'), findsOneWidget);
  });

  testWidgets('score a word and filter the Focus list by it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final lib = loadRealLibrary();
    await tester.pumpWidget(appForTest(lib, store));

    for (final (pinyin, hanzi, score) in [('nihao', '你好', 'Hard'), ('xie4xie', '谢谢', 'Easy')]) {
      await tester.enterText(find.byType(TextField), pinyin);
      await tester.pumpAndSettle();
      await tester.tap(find.text(hanzi).first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.star_border)));
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<Difficulty>), matching: find.text(score)));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    final nihao = lib.entries.firstWhere((e) => e.simplified == '你好');
    expect(store.difficulty[nihao.id], Difficulty.hard);

    // Survives a restart.
    final again = await UserStore.open();
    expect(again.difficulty[nihao.id], Difficulty.hard);

    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 words'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Hard'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 word ·'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
    expect(find.text('谢谢'), findsNothing);
  });

  testWidgets('sentences: filter, open one, see example sentences on a word', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await tester.pumpWidget(appForTest(loadRealLibrary(), store));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sentences'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();
    await tester.tap(find.text('我要一杯咖啡。').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('yì bēi', findRichText: true), findsOneWidget); // 一 tone change
    final credit = find.textContaining('Tatoeba #');
    await tester.scrollUntilVisible(credit, 300, scrollable: find.byType(Scrollable).last);
    expect(credit, findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.enterText(find.byType(TextField), 'kafei');
    await tester.pumpAndSettle();
    await tester.tap(find.text('咖啡').first);
    await tester.pumpAndSettle();
    final heading = find.text('Example sentences');
    await tester.scrollUntilVisible(heading, 300, scrollable: find.byType(Scrollable).last);
    expect(heading, findsOneWidget);
  });
}
