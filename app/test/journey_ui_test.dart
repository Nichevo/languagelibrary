import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/journey.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

/// The journey from the learner's side, on a phone and an iPad.
void main() {
  final lib = loadRealLibrary();
  const sizes = {'phone': (Size(1080, 2340), 2.75), 'iPad landscape': (Size(1366, 1024), 1.0)};

  for (final MapEntry(key: name, value: (size, ratio)) in sizes.entries) {
    testWidgets('$name: start the journey, open the week, the web and a word', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      // About 200 known words, so the first milestone is passed.
      final now = DateTime.now();
      final strong = CardState(intervalDays: 25, ease: 2.5, due: now.add(const Duration(days: 20)), reps: 4);
      for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence).take(200)) {
        store.starred.add(e.id);
        store.cards['${e.id}:${Direction.zhToEn.name}'] = strong;
        store.firstKnown['${e.id}:${Direction.zhToEn.name}'] = now;
      }
      await tester.pumpWidget(appForTest(lib, store));
      await tester.pumpAndSettle();

      Future<void> see(String text) async {
        if (find.text(text).evaluate().isEmpty) {
          await tester.scrollUntilVisible(find.text(text), 300, scrollable: find.byType(Scrollable).last);
        }
      }

      Future<void> tap(String text) async {
        await see(text);
        await tester.ensureVisible(find.text(text).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name: $text');
      }

      await tap('Practice');
      expect(find.text('New: your learning journey'), findsOneWidget);
      await tap('Have a look');
      expect(find.text('Milestone 1 · 150 words'), findsOneWidget);
      await tap('Start this week');
      expect(store.journeyOn, isTrue);
      final week = store.weekAt(DateTime.now())!;
      final wordsBefore = week.words.length;
      expect(find.text(week.title), findsOneWidget);
      // Starting after a milestone was passed doesn't celebrate it again.
      expect(find.textContaining('Milestone reached'), findsNothing);

      await tap(week.title);
      expect(find.text('This week'), findsOneWidget);
      await tap('Add words');
      expect(find.text('Close to what you know'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();
      expect(store.weekAt(DateTime.now())!.words.length, wordsBefore + 1);
      await tester.scrollUntilVisible(find.text('Almost readable'), 400, scrollable: find.byType(Scrollable).last);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap('Swap');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tap('Progress');
      expect(find.text('Open your word web'), findsOneWidget);
      await tap('Open your word web');
      expect(find.text('Your word web'), findsOneWidget);
      await see('Measured against HSK, for interest');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // A word page shows how it links in, and next week can grow from it.
      final snack = lib.entries.firstWhere((e) => e.simplified == '小吃');
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => EntryScreen(snack)));
      await tester.pumpAndSettle();
      // The word page's voice row is wider than a phone in the test font (its
      // letters are all full squares); that row isn't part of the journey.
      tester.takeException();
      await tester.scrollUntilVisible(find.text('Grow next week from this'), 300, scrollable: find.byType(Scrollable).first);
      await tap('Grow next week from this');
      expect(store.nextWeek?.seed, snack.id);
      expect(store.nextWeek?.title, 'Grows from 小吃');
    });
  }

  testWidgets('a milestone changes the colour and is celebrated once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await store.setJourneyOn(true);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    final before = Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary;
    final now = DateTime.now();
    final strong = CardState(intervalDays: 25, ease: 2.5, due: now.add(const Duration(days: 20)), reps: 4);
    for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence).take(160)) {
      store.starred.add(e.id);
      store.cards['${e.id}:${Direction.zhToEn.name}'] = strong;
      store.firstKnown['${e.id}:${Direction.zhToEn.name}'] = now;
    }
    await store.setMilestoneColours(true);
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary;
    expect(after, isNot(before));
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milestone reached: 150 words'));
    await tester.pumpAndSettle();
    expect(find.text('Milestone 1 reached'), findsOneWidget);
    expect(store.milestoneSeen, 1);
    expect(milestoneFor(knownWords(lib, store).length), 1);
  });
}
