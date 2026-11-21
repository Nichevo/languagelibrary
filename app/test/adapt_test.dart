import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/adapt.dart';
import 'package:language_library/data/journey.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/data/week_steps.dart';
import 'package:language_library/main.dart';
import 'package:language_library/models/journey_week.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/journey_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  final hsk = [for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence)) e.id];
  final w1 = DateTime(2026, 11, 2), w2 = DateTime(2026, 11, 9), w3 = DateTime(2026, 11, 16);

  JourneyWeek weekOf(DateTime start, List<String> words, {WeekAdapt? adapt, String path = 'topics'}) =>
      JourneyWeek(start: start, path: path, title: 'Week', why: 'Test', words: [...words], skill: 'cards', adapt: adapt);

  Future<UserStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return UserStore.open();
  }

  /// Answers on [ids] on [days] days from [start]: [right] of every 10 right.
  Future<void> answer(UserStore store, DateTime start, List<String> ids,
      {int days = 6, int right = 10, String method = 'meaning'}) async {
    for (var d = 0; d < days; d++) {
      for (final (i, id) in ids.indexed) {
        final ok = (i + d) % 10 < right;
        await store.logAnswer(ok ? Rating.good : Rating.again, Duration.zero, start.add(Duration(days: d, hours: 9)),
            method: method, id: id);
      }
    }
  }

  test('a good week adds about 15% more words, a hard one takes some away', () async {
    final store = await fresh();
    final words = hsk.sublist(0, 14);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(store, w2, words);
    final up = adaptFor(store, w3)!;
    expect(up.pace, 16);
    expect(up.step, 1);
    expect(up.notes.first, startsWith('16 new words, 2 more than last week: 100% right over 6 days'));

    final hard = await fresh();
    await hard.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(hard, w2, words, right: 5);
    final down = adaptFor(hard, w3)!;
    expect(down.pace, 12);
    expect(down.step, -1);

    // Fewer than 5 days: no step up.
    final short = await fresh();
    await short.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(short, w2, words, days: 3);
    expect(adaptFor(short, w3)!.pace, 14);
  });

  test('from 20 words up it takes two good weeks for each step, of 2 words at most', () async {
    final store = await fresh();
    final words = hsk.sublist(0, 20);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 20)));
    await answer(store, w2, words);
    await store.setWeekFeel(w2, 'little');
    final first = adaptFor(store, w3)!;
    expect(first.pace, 20, reason: 'one good week is not enough above 20');
    expect(first.goodRun, 1);
    expect(first.notes.first, contains('one more good week'));

    await store.startWeek(weekOf(w3, words, adapt: first));
    await answer(store, w3, words);
    await store.setWeekFeel(w3, 'little');
    final second = adaptFor(store, DateTime(2026, 11, 23))!;
    expect(second.pace, 22, reason: 'even "too little" adds 2 at most');
    expect(second.goodRun, 0, reason: 'the next step needs two more good weeks');
  });

  test('how the week felt moves it further, less far, or the other way', () async {
    final words = hsk.sublist(0, 10);
    Future<WeekAdapt> after(String? feel, {int right = 10}) async {
      final store = await fresh();
      await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 10)));
      await answer(store, w2, [...words, ...words], right: right);
      await store.setWeekFeel(w2, feel);
      return adaptFor(store, w3)!;
    }

    expect((await after(null)).pace, 12, reason: 'numbers alone: 15%');
    expect((await after('little')).pace, 13, reason: 'feeling agrees: 30%');
    expect((await after('right')).pace, 11, reason: 'about right: 10%');
    expect((await after('much')).pace, 8, reason: 'too much wins over good numbers');
    expect((await after('much', right: 5)).pace, 7, reason: 'too much and a hard week: 30% down');
  });

  test('the week before\'s words must be remembered before adding more', () async {
    final store = await fresh();
    final older = hsk.sublist(20, 30), words = hsk.sublist(0, 14);
    await store.startWeek(weekOf(w1, older, adapt: const WeekAdapt(pace: 10)));
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(store, w2, words);
    // The older words came back this week and were mostly forgotten.
    await answer(store, w2, older, days: 1, right: 5);
    final a = adaptFor(store, w3)!;
    expect(a.pace, 12);
    expect(a.notes.first, contains('only 5 of 10 words from the week before were remembered'));
  });

  test('practice types: easy ones get shorter, hard ones get an extra short round', () async {
    final store = await fresh();
    final words = hsk.sublist(0, 12);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 12)));
    await answer(store, w2, words, days: 2, method: 'listen');
    await answer(store, w2, words, days: 2, right: 3, method: 'type');
    await answer(store, w2, words, days: 2, right: 7, method: 'meaning');
    final a = adaptFor(store, w3)!;
    expect(a.typeLevel('listen'), 1);
    expect(a.typeLevel('type'), -1);
    expect(a.typeLevel('meaning'), 0);
    expect(a.notes, contains(startsWith('Type the pinyin: 10 of 24 right, so it gets an extra short round')));

    final next = weekOf(w3, hsk.sublist(30, 42), adapt: a);
    final wed = DateTime(2026, 11, 18, 9);
    final mon = daySteps(store, next, 0, wed)!;
    expect(mon[2].kind, StepKind.listen);
    expect(mon[2].ids.length, 3, reason: 'hearing is easy: every other word');
    final wedSteps = daySteps(store, next, 2, wed)!;
    expect(wedSteps.map((s) => s.kind), [StepKind.cards, StepKind.recall, StepKind.type]);
    expect(wedSteps.last.extra, 'needs more');
    expect(wedSteps.last.ids.length, extraWords);
  });

  test('a type only gets harder when the words do not', () async {
    final store = await fresh();
    final words = hsk.sublist(0, 14);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(store, w2, words);
    final a = adaptFor(store, w3)!;
    expect(a.pace, 16);
    expect(a.typeLevel('meaning'), 0, reason: 'more words this week, so meaning stays as it was');
  });

  test('hard practices never grow with the words', () async {
    final store = await fresh();
    final week = weekOf(w3, hsk.sublist(0, 40), adapt: const WeekAdapt(pace: 40, types: {'type': 1}));
    final wed = DateTime(2026, 11, 18, 9);
    for (final day in [0, 1]) {
      expect(daySteps(store, week, day, wed)!.firstWhere((s) => s.kind == StepKind.sayIt).ids.length, hardCap);
    }
    expect(daySteps(store, week, 4, wed)!.firstWhere((s) => s.kind == StepKind.type).ids.length, hardCap ~/ 2);
    // Two hard types needing more: only one extra hard round a day.
    final both = weekOf(w3, hsk.sublist(0, 20), adapt: const WeekAdapt(pace: 20, types: {'type': -1, 'speak': -1}));
    final extras = extraSteps(store, both, wed);
    expect(extras.map((s) => s.kind), [StepKind.type]);
  });

  test('keeping last week\'s settings, switching off, and a review week', () async {
    final store = await fresh();
    final words = hsk.sublist(0, 14);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14, types: {'listen': 1})));
    await answer(store, w2, words);
    await store.setKeepNext(w2, true);
    final kept = adaptFor(store, w3)!;
    expect(kept.pace, 14);
    expect(kept.types, {'listen': 1});
    expect(kept.notes, ['You kept last week\'s settings']);

    await store.setAdaptOn(false);
    expect(adaptFor(store, w3), isNull);
    await store.setAdaptOn(true);

    final review = await fresh();
    await review.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14), path: 'review'));
    expect(adaptFor(review, w3)!.pace, 14);

    // Choosing a pace yourself starts again from there.
    await store.setKeepNext(w2, false);
    await store.setJourneyPace(10);
    expect(adaptFor(store, w3)!.pace, 12);
  });

  test('adjustments survive a save', () async {
    final store = await fresh();
    const a = WeekAdapt(pace: 17, step: 1, goodRun: 1, types: {'type': -1}, notes: ['Why']);
    await store.startWeek(weekOf(w3, hsk.sublist(0, 17), adapt: a));
    await store.setWeekFeel(w3, 'right');
    final back = JourneyWeek.fromJson(store.weeks.single.toJson());
    expect(back.adapt!.toJson(), a.toJson());
    expect(back.feel, 'right');
  });

  test('a new week is planned with the adjusted number of words', () async {
    final store = await fresh();
    for (final id in hsk.take(150)) {
      store.starred.add(id);
    }
    final words = hsk.sublist(0, 14);
    await store.startWeek(weekOf(w2, words, adapt: const WeekAdapt(pace: 14)));
    await answer(store, w2, words);
    final w = planWeek(lib, store, w3, 'connections')!;
    expect(w.adapt!.pace, 16);
    expect(w.words.length, 16);
  });

  testWidgets('the recap asks how the week felt and shows next week', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = await fresh();
    await store.setJourneyOn(true);
    final words = hsk.sublist(0, 14);
    final week = weekOf(w2, words, adapt: const WeekAdapt(pace: 14));
    await store.startWeek(week);
    await answer(store, w2, words);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute(builder: (_) => RecapScreen(week: week)));
    await tester.pumpAndSettle();
    expect(find.text('How did the week feel?'), findsOneWidget);
    expect(find.text('Next week'), findsOneWidget);
    expect(find.text('14 → 16'), findsOneWidget);
    await tester.tap(find.text('Too much'));
    await tester.pumpAndSettle();
    expect(store.weeks.firstWhere((w) => w.start == w2).feel, 'much');
    expect(find.text('14 → 12'), findsOneWidget);
  });
}
