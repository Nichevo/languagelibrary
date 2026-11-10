import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/device/device.dart';
import 'package:language_library/main.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/practice_home.dart';
import 'package:language_library/ui/stats_screen.dart';
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
    final measure = find.text('Its measure word').first;
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

  testWidgets('levels and content: switch a level on', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await tester.pumpWidget(appForTest(loadRealLibrary(), store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.text('HSK 1–3 and the phrasebook'), findsOneWidget);
    await tester.tap(find.text('Levels and content'));
    await tester.pumpAndSettle();
    final hsk4 = find.widgetWithText(SwitchListTile, 'HSK 4');
    expect(tester.widget<SwitchListTile>(hsk4).value, isFalse);
    await tester.tap(hsk4);
    await tester.pumpAndSettle();
    expect(store.levels, {1, 2, 3, 4});
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('HSK 1–4 and the phrasebook'), findsOneWidget);
  });

  testWidgets('settings: reminder, tone colours, backup and restore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final device = NoDevice();
    final lib = loadRealLibrary();
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store, device: device));
    await store.toggleStar(lib.entries.first.id);

    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Daily reminder'), 200, scrollable: list);
    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(store.reminderOn, isTrue);
    expect(find.text('Reminder time'), findsOneWidget);
    await tester.tap(find.text('Colour characters by tone'));
    await tester.pumpAndSettle();
    expect(store.toneHanzi, isFalse);

    await tester.scrollUntilVisible(find.text('Back up to a file'), 200, scrollable: list);
    await tester.tap(find.text('Back up to a file'));
    await tester.pumpAndSettle();
    expect(device.saved.keys.single, startsWith('language-library-backup-'));
    expect(find.textContaining('Saved language-library-backup-'), findsOneWidget);

    // Restore that file after unstarring.
    device.nextOpen = device.saved.values.single;
    await store.toggleStar(lib.entries.first.id);
    expect(store.starred, isEmpty);
    await tester.tap(find.text('Restore from a file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(store.starred, [lib.entries.first.id]);
    expect(find.text('Restored 1 starred word.'), findsOneWidget);
  });

  testWidgets('opening from a widget goes to the right place', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final device = NoDevice();
    final lib = loadRealLibrary();
    await tester.pumpWidget(appForTest(lib, store, device: device));
    expect(find.text('Word of the day'), findsOneWidget);

    device.open('practice');
    await tester.pumpAndSettle();
    expect(find.text('All starred words'), findsOneWidget);

    final coffee = lib.entries.firstWhere((e) => e.simplified == '咖啡');
    device.open('entry/${coffee.id}');
    await tester.pumpAndSettle();
    expect(find.text('Female voice'), findsOneWidget);
    expect(find.textContaining('kā', findRichText: true), findsWidgets);
  });

  testWidgets('progress tab and storage use', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final lib = loadRealLibrary();
    tester.view.physicalSize = const Size(1080, 2340); // a phone screen
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    final w = lib.entries.first;
    await store.toggleStar(w.id);
    final now = DateTime.now();
    await store.recordReview(
        w.id, Direction.zhToEn, const Scheduler().review(null, Rating.good, now), Rating.good,
        const Duration(seconds: 90), now);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Cards answered'), findsOneWidget);
    expect(find.text('1 min'), findsWidgets);
    expect(find.text('Words right 3+ in a row'), findsOneWidget);
    expect(find.text('Where to focus'), findsOneWidget);
    // The rest of the page builds: answers of several kinds, then scroll through it.
    for (final (i, m) in ['listen', 'meaning', 'listen', 'pinyin', 'type'].indexed) {
      await store.logAnswer(i.isEven ? Rating.good : Rating.again, const Duration(seconds: 5), now,
          method: m, id: w.id);
    }
    await tester.pumpAndSettle();
    final stats = find.descendant(of: find.byType(StatsView), matching: find.byType(Scrollable)).first;
    for (final title in [
      'Cards by status',
      'Right in a row',
      'Practice methods over time',
      'Over time',
      'Listening and reading',
      'Words that trip you up',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 300, scrollable: stats);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Practise these'), findsOneWidget);
    // Charts by day, week or month: the choice is remembered.
    await tester.scrollUntilVisible(find.text('Charts by'), -300, scrollable: stats);
    expect(find.text('Where to focus'), findsOneWidget);
    expect(find.text('Trends we noticed'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(store.statsPeriod, 'month');
    expect(find.text('Last 6 months, in minutes'), findsOneWidget);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Last 14 days, in minutes'), findsOneWidget);

    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(PracticeHome), matching: find.byType(Scrollable)).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    // The sizes themselves are checked in daily_test.dart.
    expect(find.text('Space on this phone'), findsOneWidget);
  });
}
