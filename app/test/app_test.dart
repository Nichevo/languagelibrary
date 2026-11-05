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
    await tester.tap(find.byIcon(Icons.star_border).first);
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
}
