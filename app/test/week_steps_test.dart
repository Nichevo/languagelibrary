import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/data/week_steps.dart';
import 'package:language_library/main.dart';
import 'package:language_library/models/journey_week.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/week_day_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  final monday = DateTime(2026, 11, 16);
  final friday = DateTime(2026, 11, 20, 10);
  final words = [for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence).skip(40).take(6)) e.id];

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

  test('each practice day is a mix of practice types, easy to hard', () async {
    final store = await fresh();
    final week = weekOf(words);
    List<StepKind>? kinds(int day) => daySteps(store, week, day, friday)?.map((s) => s.kind).toList();

    expect(kinds(0), [StepKind.meet, StepKind.meaning, StepKind.listen, StepKind.sayIt]);
    expect(daySteps(store, week, 0, friday)!.first.ids, words.sublist(0, 3));
    expect(daySteps(store, week, 1, friday)!.first.ids, words.sublist(3));
    // Tuesday hears Monday's words again too.
    expect(daySteps(store, week, 1, friday)![2].ids, [...words.sublist(3), ...words.sublist(0, 3)]);
    expect(kinds(2), [StepKind.cards, StepKind.recall]);
    expect(kinds(3), isNull, reason: 'the practice-type day stays as it is');
    expect(kinds(4), [StepKind.mixed, StepKind.type, StepKind.dueCards]);
    expect(kinds(5), isNull);
    expect(kinds(6), isNull);
    expect(daySteps(store, weekOf(words, path: 'review'), 2, friday)!.map((s) => s.kind), [
      StepKind.mixed,
      StepKind.dueCards,
    ]);

    await store.setWeekMix(false);
    expect(kinds(0), isNull, reason: 'switched off: flashcards as before');
  });

  test('the mixed round asks what went wrong on each word, then what was used least', () async {
    final store = await fresh();
    final week = weekOf(words);
    final wed = DateTime(2026, 11, 18, 9);
    // Word 0: missed when heard. Word 1: right on its meaning, twice.
    await store.logAnswer(Rating.again, const Duration(seconds: 3), wed, method: 'listen', id: words[0]);
    await store.logAnswer(Rating.good, const Duration(seconds: 3), wed, method: 'meaning', id: words[0]);
    await store.logAnswer(Rating.good, const Duration(seconds: 3), wed, method: 'meaning', id: words[1]);
    await store.logAnswer(Rating.good, const Duration(seconds: 3), wed, method: 'meaning', id: words[1]);
    // Today's answers don't change the day's plan part way through.
    await store.logAnswer(Rating.again, const Duration(seconds: 3), friday, method: 'pinyin', id: words[2]);

    final k = mixedKinds(store, week, words, friday);
    expect(k[words[0]], 'listen');
    expect(k[words[1]], isNot('meaning'));
    expect(k[words[2]], isNot('pinyin'));
    // With nothing to go on, the words spread over the kinds.
    expect({for (final id in words.sublist(2)) k[id]}.length, greaterThan(1));
    expect(
      mixedKinds(store, week, [words[3]], friday, canOrder: (_) => true).values.single,
      isIn([...choiceMethods, 'order']),
    );

    // The most missed word types its pinyin first.
    expect(mostMissed(store, week, friday, 2), [words[0], words[1]]);
  });

  test('a step is done when its words are, and only today counts', () async {
    final store = await fresh();
    final now = DateTime.now();
    final week = weekOf(words, start: DateTime(now.year, now.month, now.day));
    final steps = daySteps(store, week, 0, now)!;
    expect(nextStepIndex(store, week, 0, steps, now), 0);
    for (final id in steps[0].ids) {
      await store.markStepDone(stepKey(week, 0, 0, now), id);
    }
    expect(stepComplete(store, week, 0, 0, steps[0], now), isTrue);
    expect(nextStepIndex(store, week, 0, steps, now), 1);
    final tomorrow = now.add(const Duration(days: 1));
    expect(stepComplete(store, week, 0, 0, steps[0], tomorrow), isFalse);
    // Marking a step tomorrow forgets today's.
    await store.markStepDone(stepKey(week, 0, 1, tomorrow), words[0]);
    expect(store.weekSteps.keys, [stepKey(week, 0, 1, tomorrow)]);
    // Say it counts words tried today.
    await store.logSpeakTry(steps[3].ids.first, false, now);
    expect(stepDone(store, week, 0, 3, steps[3], now), {steps[3].ids.first});
  });

  test('the recap names the practice type that went best and the one to work on', () async {
    final store = await fresh();
    final week = weekOf(words);
    final wed = DateTime(2026, 11, 18, 9);
    for (var i = 0; i < 6; i++) {
      await store.logAnswer(Rating.good, Duration.zero, wed, method: 'listen', id: words[i]);
      await store.logAnswer(i < 2 ? Rating.good : Rating.again, Duration.zero, wed, method: 'pinyin', id: words[i]);
    }
    await store.logAnswer(Rating.good, Duration.zero, wed, method: 'type', id: words[0]);
    final r = methodResults(store, week);
    expect([for (final x in r) x.$1], ['listen', 'pinyin'], reason: 'type has too few answers');
    expect(r.last.$2, 2);
  });

  testWidgets('Monday: meet the words, then pick their meaning, then hear them', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = await fresh();
    final now = DateTime.now();
    final week = weekOf(words, start: DateTime(now.year, now.month, now.day));
    final steps = daySteps(store, week, 0, now)!;
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (_) => WeekDayScreen(week: week, day: 0, steps: steps),
          ),
        );
    await tester.pumpAndSettle();

    // Straight into the first step.
    expect(find.text('Meet each word'), findsOneWidget);
    expect(find.text('Word 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: See it, pick the meaning'));
    await tester.pumpAndSettle();

    // Answer every question with the first choice; wrong ones come back, at most twice.
    expect(find.text('What does it mean?'), findsOneWidget);
    for (var i = 0; i < 12 && find.text('What does it mean?').evaluate().isNotEmpty; i++) {
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(stepComplete(store, week, 0, 1, steps[1], now), isTrue);
    expect(store.reviews.every((r) => r.method == 'meaning'), isTrue);
    await tester.tap(find.text('Next: Hear it, pick the word'));
    await tester.pumpAndSettle();
    expect(find.text('Which word did you hear?'), findsOneWidget);

    // Leaving part way comes back to the day, which carries on from there.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Carry on: step 3 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
