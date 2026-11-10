import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/daily.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/data/widget_feed.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();

  test('quick questions: starred words first, four different meanings, one right', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final words = lib.entries.where((e) => !e.isSentence && e.hsk == 2).take(6).toList();
    for (final e in words) {
      await store.toggleStar(e.id);
    }
    final qs = quizQuestions(lib, store, Random(3));
    expect({for (final q in qs) q['id']}, {for (final e in words) e.id});
    for (final q in qs) {
      final opts = q['opts'] as List;
      expect(opts.length, 4);
      expect(opts.toSet().length, 4);
      expect(opts[q['right'] as int], lib.byId[q['id']]!.gloss);
    }
  });

  test('quick questions fall back to HSK 1 words when little is starred', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final qs = quizQuestions(lib, store, Random(1));
    expect(qs.length, 40);
    expect(qs.every((q) => lib.byId[q['id']]!.hsk == 1), isTrue);
  });

  test('every quick-question kind: four different answers, the right one is the word\'s', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    for (final kind in QuizKind.values) {
      final qs = quizQuestions(lib, store, Random(5), kind: kind);
      expect(qs.length, greaterThan(10), reason: kind.name);
      for (final q in qs) {
        final opts = (q['opts'] as List).cast<String>();
        final e = lib.byId[q['id']]!;
        final right = opts[q['right'] as int];
        expect(opts.length, 4);
        expect(opts.toSet().length, 4, reason: '$kind ${q['big']} $opts');
        expect(q['method'], kind.method);
        expect(q['title'], kind.title);
        switch (kind) {
          case QuizKind.meaning:
            expect(right, e.gloss);
            expect(q['big'], e.simplified);
          case QuizKind.which:
            expect(right, e.simplified);
            expect(q['big'], e.gloss);
          case QuizKind.pinyin:
            expect(right, e.pinyin);
            expect(q['big'], e.simplified);
          case QuizKind.opposite:
            expect(q['big'], e.simplified);
            final pair = lib.opposites.firstWhere((p) =>
                (p.a.id == e.id && p.b.simplified == right) || (p.b.id == e.id && p.a.simplified == right));
            expect(q['wrongMsg'], contains(right), reason: '$pair');
        }
      }
    }
    expect(QuizKind.meaning.method, 'widget');
    expect(QuizKind.opposite.method, 'widgetOpposite');
  });

  test('the mixed widget takes turns between kinds', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final qs = mixedQuestions(lib, store, Random(2));
    expect(qs.length, 40);
    expect({for (final q in qs.take(4)) q['kind']}, {for (final k in QuizKind.values) k.name});
    expect(qs.every((q) => (q['title'] as String).startsWith(mixPrefix)), isTrue);
    final firsts = {for (var seed = 0; seed < 12; seed++) mixedQuestions(lib, store, Random(seed)).first['kind']};
    expect(firsts.length, greaterThan(1), reason: 'the first kind changes');
  });

  test('scale of the day takes turns and covers a month', () {
    final today = DateTime(2026, 11, 9);
    final days = scaleDays(lib, today);
    expect(days.length, 31);
    expect(days.first['d'], dayKey(today));
    expect(days[0]['i'], isNot(days[1]['i']));
    final first = lib.scales[days.first['i'] as int];
    expect(days.first['name'], first.name);
    expect((days.first['words'] as List).length, first.items.length);
    expect({for (final d in days) d['i']}.length, lib.scales.length);
  });

  test('quiz widget answers are added to the practice log once, in time order', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final t = DateTime(2026, 11, 10, 9);
    await store.logAnswer(Rating.good, const Duration(seconds: 5), t.add(const Duration(minutes: 10)),
        method: 'meaning', id: 'later');
    final ms = t.millisecondsSinceEpoch;
    final log = '[{"id":"a","ok":true,"at":$ms,"ms":4000,"method":"widgetPinyin"},'
        '{"id":"b","ok":false,"at":${ms + 60000},"ms":900000},'
        '{"bad":1}]';
    final answers = widgetAnswers(log);
    expect(answers.length, 2, reason: 'unreadable entries are skipped');
    expect(await store.addWidgetAnswers(answers), 2);
    expect([for (final r in store.reviews) r.id], ['a', 'b', 'later']);
    final a = store.reviews.first;
    expect(a.method, 'widgetPinyin');
    expect(store.reviews[1].method, 'widget', reason: 'answers logged before the kinds existed');
    expect(a.right, isTrue);
    expect(a.spent, const Duration(seconds: 4));
    expect(store.reviews[1].right, isFalse);
    expect(store.reviews[1].spent, UserStore.maxSpent, reason: 'time on one answer is capped');
    // The same log read again adds nothing; a newer answer is added.
    expect(await store.addWidgetAnswers(answers), 0);
    final more = widgetAnswers('[{"id":"c","ok":true,"at":${ms + 120000}}]');
    expect(await store.addWidgetAnswers(more), 1);
    expect(store.reviews.where((r) => r.method.startsWith('widget')).length, 3);
    expect(widgetAnswers(null), isEmpty);
    expect(widgetAnswers('not json'), isEmpty);
  });
}
