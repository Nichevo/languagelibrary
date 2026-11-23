import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:language_library/data/method_stats.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/srs/scheduler.dart';

void main() {
  final t0 = DateTime(2026, 11, 1, 9);
  var minute = 0;
  Review r(String method, String id, bool right, {bool isNew = false}) => Review(
        t0.add(Duration(minutes: minute++)),
        const Duration(seconds: 10),
        right ? Rating.good : Rating.again,
        isNew,
        method: method,
        id: id,
      );

  test('compares how words were remembered on their next flashcard', () {
    final reviews = <Review>[];
    // Ten words practised with "pick the meaning" between flashcards: all remembered.
    for (var i = 0; i < 10; i++) {
      reviews
        ..add(r('cards', 'm$i', true, isNew: true))
        ..add(r('meaning', 'm$i', true))
        ..add(r('cards', 'm$i', true));
    }
    // Ten words with flashcards alone: half remembered.
    for (var i = 0; i < 10; i++) {
      reviews
        ..add(r('cards', 'c$i', true, isNew: true))
        ..add(r('cards', 'c$i', i.isEven));
    }
    // Three typed words: not enough to compare yet.
    for (var i = 0; i < 3; i++) {
      reviews
        ..add(r('type', 't$i', false))
        ..add(r('cards', 't$i', true));
    }
    final stats = {for (final s in methodStats(reviews, t0)) s.method: s};
    expect(stats['meaning']!.rememberRate, 1.0);
    expect(stats['meaning']!.tested, 10);
    expect(stats['cards']!.tested, 10, reason: 'first-ever cards are not a memory test');
    expect(stats['cards']!.rememberRate, 0.5);
    expect(stats['type']!.tested, 3);
    expect(stats['type']!.rightRate, 0.0);
    expect(bestMethod(stats.values.toList())!.method, 'meaning');
  });

  test('answers saved before methods were recorded still load', () {
    final old = Review.fromJson([1700000000, 5000, 2, 0]);
    expect(old.method, 'cards');
    expect(old.id, isNull);
    final now = Review.fromJson(r('pinyin', 'x', true).toJson());
    expect(now.method, 'pinyin');
    expect(now.id, 'x');
    expect(methodStats([old], DateTime(2020)).single.tested, 0);
  });

  test('right in a row: a miss starts the run again at 0', () {
    final runs = rightInARow([
      r('cards', 'a', true),
      r('meaning', 'a', true),
      r('listen', 'a', false),
      r('type', 'a', true),
      r('cards', 'b', true),
      r('order', 'b', true),
      r('cards', 'c', false),
    ]);
    expect(runs, {'a': 1, 'b': 2, 'c': 0});
  });

  test('right in a row: a flashcard\'s first look is not an answer', () {
    final runs = rightInARow([
      r('cards', 'a', true, isNew: true),
      r('meaning', 'a', true),
      r('listen', 'a', true),
    ]);
    expect(runs, {'a': 2});
  });

  test('known from practice: 3 right in a row on 2 days or more, any practice', () {
    Review at(int day, String id, bool right, {bool isNew = false, String method = 'meaning'}) =>
        Review(DateTime(2026, 11, day, 10), Duration.zero, right ? Rating.good : Rating.again, isNew, method: method, id: id);
    final known = UserStore.knownFromPractice([
      // a: right 3 times on one day only, then once more the next day.
      at(1, 'a', true), at(1, 'a', true), at(1, 'a', true), at(2, 'a', true),
      // b: a miss in between starts again.
      at(1, 'b', true), at(1, 'b', true), at(2, 'b', false), at(2, 'b', true), at(3, 'b', true),
      // c: the first flashcard look doesn't count.
      at(1, 'c', true, isNew: true, method: 'cards'), at(1, 'c', true), at(2, 'c', true),
      // d: once known it stays known.
      at(1, 'd', true), at(2, 'd', true), at(3, 'd', true), at(4, 'd', false),
    ]);
    expect(known, {'a': DateTime(2026, 11, 2, 10), 'd': DateTime(2026, 11, 3, 10)});
  });

  test('answers by week and method, oldest week first', () {
    final today = DateTime(2026, 11, 9);
    Review at(DateTime t, String method, bool right) =>
        Review(t, const Duration(seconds: 4), right ? Rating.good : Rating.again, false, method: method, id: 'x');
    final weeks = methodWeeks([
      at(DateTime(2026, 11, 9, 20), 'cards', true),
      at(DateTime(2026, 11, 3, 8), 'cards', false),
      at(DateTime(2026, 11, 2, 23), 'listen', true), // the week before
      at(DateTime(2026, 9, 1), 'listen', true), // too old
      at(DateTime(2026, 11, 10, 1), 'listen', true), // tomorrow
    ], today);
    expect(weeks.length, 8);
    expect(weeks.last['cards'], (answers: 2, right: 1));
    expect(weeks.last.containsKey('listen'), isFalse);
    expect(weeks[6]['listen'], (answers: 1, right: 1));
    expect(weeks.take(6).every((w) => w.isEmpty), isTrue);
  });

  test('recall, listening and reading counts', () {
    final reviews = [
      r('cards', 'a', true, isNew: true),
      r('cards', 'a', false),
      r('cards', 'b', true),
      r('listen', 'a', true),
      r('meaning', 'a', false),
      r('pinyin', 'a', true),
    ];
    expect(countOf(reviews, isRecall), (answers: 2, right: 1));
    expect(countOf(reviews, isListening), (answers: 1, right: 1));
    expect(countOf(reviews, isReading), (answers: 2, right: 1));
  });

  test('words that trip you up: missed twice or more, most missed first', () {
    final reviews = [
      for (var i = 0; i < 3; i++) r('cards', 'a', false),
      r('cards', 'a', true),
      r('listen', 'b', false),
      r('meaning', 'b', false),
      r('cards', 'c', false),
      r('cards', 'c', true),
    ];
    final tricky = trickyWords(reviews, t0);
    expect(tricky, [('a', 3, 4), ('b', 2, 2)]);
    expect(trickyWords(reviews, t0.add(const Duration(days: 1))), isEmpty);
  });

  test('cards learned: the first time a card becomes familiar is kept', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final day = DateTime(2026, 11, 5);
    final week = CardState(reps: 3, intervalDays: 8, ease: 2.5, due: day.add(const Duration(days: 8)));
    // A card already familiar before this was recorded gets the unknown date.
    SharedPreferences.setMockInitialValues({
      'user_state_v1': '{"cards":{"old:zhToEn":{"reps":4,"interval":30,"ease":2.5,"due":"2026-12-01T00:00:00.000"}}}',
    });
    final store = await UserStore.open();
    expect(store.firstKnown['old:zhToEn'], UserStore.unknownDate);
    final short = CardState(reps: 1, intervalDays: 1, ease: 2.5, due: day);
    await store.recordReview('a', Direction.zhToEn, short, Rating.good, Duration.zero, day);
    expect(store.firstKnown.containsKey(UserStore.cardKey('a', Direction.zhToEn)), isFalse);
    await store.recordReview('a', Direction.zhToEn, week, Rating.good, Duration.zero, day);
    final later = day.add(const Duration(days: 9));
    await store.recordReview('a', Direction.zhToEn, week, Rating.good, Duration.zero, later);
    expect(store.firstKnown[UserStore.cardKey('a', Direction.zhToEn)], day);
  });
}
