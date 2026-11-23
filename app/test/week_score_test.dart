import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/daily.dart';
import 'package:language_library/data/journey.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/data/week_score.dart';
import 'package:language_library/data/week_steps.dart';
import 'package:language_library/main.dart';
import 'package:language_library/models/journey_week.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/week_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  final monday = DateTime(2026, 11, 16);
  final words = [for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence).skip(40).take(24)) e.id];

  JourneyWeek weekOf(List<String> ids, {String path = 'topics', DateTime? start}) => JourneyWeek(
        start: start ?? monday,
        path: path,
        title: 'Test week',
        why: 'For the tests',
        words: [...ids],
        skill: 'speak',
      );

  Future<UserStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return UserStore.open();
  }

  Future<void> answer(UserStore store, String id, String method, bool right, DateTime at) =>
      store.logAnswer(right ? Rating.good : Rating.again, const Duration(seconds: 3), at, method: method, id: id);

  test('the held set: at most 20 words, kinds take turns, first answers from when they were met', () async {
    final store = await fresh();
    final week = weekOf(words);
    final mon = DateTime(2026, 11, 16, 9), tue = DateTime(2026, 11, 17, 9);
    await answer(store, words[0], 'meaning', true, mon);
    await answer(store, words[0], 'meaning', false, tue); // later: not the first
    await answer(store, words[1], 'listen', false, mon);
    await answer(store, words[2], 'listen', true, mon); // turn is meaning, only listen asked
    await answer(store, words[3], 'pinyin', true, mon); // not a check kind
    await answer(store, words[4], 'meaning', true, DateTime(2026, 11, 22, 9)); // on Sunday: too late

    final h = heldFor(store, week);
    expect(h.kinds.length, checkWords);
    expect(h.kinds.keys, words.take(checkWords));
    expect(h.kinds[words[0]], 'meaning');
    expect(h.kinds[words[1]], 'listen');
    expect(h.kinds[words[2]], 'listen', reason: 'falls back to the kind that was asked');
    expect(h.kinds[words[3]], 'listen');
    expect(h.first, {words[0]: true, words[1]: false, words[2]: true});
  });

  test('Sunday check, score and a check-back five weeks later', () async {
    final store = await fresh();
    final week = weekOf(words.take(4).toList());
    await store.startWeek(week);
    final mon = DateTime(2026, 11, 16, 9);
    for (final id in week.words) {
      await answer(store, id, 'meaning', true, mon);
      await answer(store, id, 'listen', true, mon);
    }
    expect(canCheck(week, DateTime(2026, 11, 21, 9)), isFalse, reason: 'not before Sunday');
    final sunday = DateTime(2026, 11, 22, 9);
    expect(canCheck(week, sunday), isTrue);
    expect(canCheck(week, DateTime(2026, 11, 29, 9)), isTrue, reason: 'still open the week after');
    expect(canCheck(week, DateTime(2026, 11, 30, 9)), isFalse);
    expect(canCheck(weekOf(words, path: 'review'), sunday), isFalse);

    final reviews = store.reviews.length;
    await saveCheck(store, week, {for (final (i, id) in week.words.indexed) id: i != 3}, sunday);
    expect(store.reviews.length, reviews, reason: 'check answers stay out of the practice answers');
    final saved = store.weeks.single;
    expect(canCheck(saved, sunday), isFalse);
    var s = weekScores(store).single;
    expect((s.first, s.sunday, s.back), (100, 75, null));
    expect(s.keptToSunday, (3, 4));

    // Five weeks after the Sunday.
    expect(canCheckBack(store, saved, DateTime(2026, 12, 26, 9)), isFalse);
    final backDay = DateTime(2026, 12, 27, 9);
    expect(canCheckBack(store, saved, backDay), isTrue);
    expect(checkBacksDue(store, backDay), [saved]);
    expect(canCheckBack(store, saved, DateTime(2027, 1, 3, 9)), isFalse);
    await saveCheck(store, saved, {for (final (i, id) in week.words.indexed) id: i != 0 && i != 3}, backDay, back: true);
    s = weekScores(store).single;
    expect(s.back, 50);
    expect(s.heldToBack, (2, 3));
    expect(checkBacksDue(store, backDay), isEmpty);

    // Saved and read back.
    final again = JourneyWeek.fromJson(store.weeks.single.toJson()).held!;
    expect(again.kinds, s.held.kinds);
    expect(again.first, s.held.first);
    expect(again.sunday, s.held.sunday);
    expect(again.back, s.held.back);
    expect(again.backAt, DateTime.fromMillisecondsSinceEpoch(backDay.millisecondsSinceEpoch ~/ 1000 * 1000));
  });

  test('a week with no Sunday check still gets a check-back', () async {
    final store = await fresh();
    final week = weekOf(words.take(3).toList());
    await store.startWeek(week);
    await answer(store, words[0], 'meaning', true, DateTime(2026, 11, 16, 9));
    expect(canCheckBack(store, week, DateTime(2026, 12, 27, 9)), isTrue);
    final empty = weekOf(words.skip(10).take(3).toList(), start: DateTime(2026, 11, 23));
    expect(canCheckBack(store, empty, DateTime(2027, 1, 3, 9)), isFalse, reason: 'nothing to compare with');
  });

  test('words that slip at a check-back cycle back in', () async {
    final store = await fresh();
    final old = weekOf(words.take(4).toList());
    await store.startWeek(old);
    final backDay = DateTime(2026, 12, 27, 9);
    await saveCheck(store, old, {for (final (i, id) in old.words.indexed) id: i != 1}, backDay, back: true);

    final now = weekOf(words.skip(10).take(6).toList(), start: DateTime(2026, 12, 28));
    await store.startWeek(now);
    expect(cycleBackWords(store, backDay), isEmpty, reason: 'not the same day');
    final friday = DateTime(2027, 1, 1, 9);
    expect(cycleBackWords(store, friday), [words[1]]);
    final steps = daySteps(store, now, 4, friday)!;
    expect(steps[1].kind, StepKind.mixed);
    expect(steps[1].ids, [words[1]]);
    expect(steps[1].extra, isNotNull);

    // The next review week starts with it.
    final review = planWeek(lib, store, DateTime(2027, 1, 4), 'review')!;
    expect(review.words.first, words[1]);

    // Right twice since: it has come back.
    await answer(store, words[1], 'meaning', true, DateTime(2026, 12, 29, 9));
    await answer(store, words[1], 'listen', true, DateTime(2026, 12, 30, 9));
    expect(cycleBackWords(store, friday), isEmpty);
    expect(daySteps(store, now, 4, friday)!.map((s) => s.kind), [StepKind.mixed, StepKind.type, StepKind.dueCards]);
  });

  testWidgets('taking the week check on Sunday shows the score', (tester) async {
    final store = await fresh();
    final today = dayOf(DateTime.now());
    final ids = words.take(3).toList();
    final week = weekOf(ids, start: today.subtract(const Duration(days: 6)));
    await store.startWeek(week);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute(builder: (_) => WeekScoreScreen(week: week)));
    await tester.pumpAndSettle();
    expect(find.text('Week check · 3 words'), findsOneWidget);
    await tester.tap(find.text('Start check'));
    await tester.pumpAndSettle();
    final kinds = heldFor(store, week).kinds;
    for (final id in ids) {
      final e = lib.byId[id]!;
      await tester.tap(find.text(kinds[id] == 'meaning' ? e.gloss : e.simplified).last);
      await tester.pumpAndSettle();
      expect(find.text('Right!'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('See the score'));
    await tester.pumpAndSettle();
    expect(store.weeks.single.held!.sunday, {for (final id in ids) id: true});
    expect(store.reviews, isEmpty);
    expect(find.text('This week\'s score: 100%'), findsOneWidget);
  });
}
