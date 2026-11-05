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
}
