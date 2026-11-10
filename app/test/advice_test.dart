import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/advice.dart';
import 'package:language_library/data/method_stats.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final today = DateTime(2026, 11, 11, 9);

  Review r(DateTime at, String method, bool right, {String id = 'w', bool isNew = false, int secs = 5}) =>
      Review(at, Duration(seconds: secs), right ? Rating.good : Rating.again, isNew, method: method, id: id);

  group('Period', () {
    test('days, weeks and calendar months', () {
      expect(Period.day.indexOf(today, today), 13);
      expect(Period.day.indexOf(DateTime(2026, 11, 10, 23), today), 12);
      expect(Period.day.indexOf(DateTime(2026, 10, 29), today), 0);
      expect(Period.day.indexOf(DateTime(2026, 10, 28), today), isNull);
      expect(Period.week.indexOf(DateTime(2026, 11, 5), today), 7);
      expect(Period.week.indexOf(DateTime(2026, 11, 4), today), 6);
      expect(Period.month.indexOf(DateTime(2026, 11, 1), today), 5);
      expect(Period.month.indexOf(DateTime(2026, 10, 31), today), 4);
      expect(Period.month.indexOf(DateTime(2026, 6, 1), today), 0);
      expect(Period.month.indexOf(DateTime(2026, 5, 31), today), isNull);
      expect(Period.month.indexOf(DateTime(2026, 11, 12), today), isNull, reason: 'the future');
      expect(Period.month.labels(today), ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']);
      expect(Period.week.labels(today).last, '5/11');
      expect(Period.day.labels(today).last, 'W');
      expect(Period.byName('nonsense'), Period.week);
    });
  });

  test('tips: listening behind, forgetting flashcards, tricky words', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final t = today.subtract(const Duration(days: 2));
    for (var i = 0; i < 20; i++) {
      store.reviews
        ..add(r(t, 'listen', i % 2 == 0, id: 'l$i'))
        ..add(r(t, 'meaning', i % 10 != 0, id: 'm$i'))
        ..add(r(t, 'cards', i % 3 != 0, id: 'c$i'));
    }
    for (var i = 0; i < 3; i++) {
      for (var k = 0; k < 2; k++) {
        store.reviews.add(r(t, 'type', false, id: 'x$i'));
      }
    }
    final all = tips(store, today, limit: 10);
    final titles = [for (final tip in all) tip.title];
    expect(titles, contains('Your listening is behind your reading'));
    expect(titles.any((s) => s.startsWith('You remembered 65%')), isTrue);
    expect(titles, contains('3 words keep tripping you up'));
    expect(all.firstWhere((tip) => tip.title.contains('tripping')).action, TipAction.practiseTricky);
    expect(tips(store, today).length, 3, reason: 'the top three only');
  });

  test('tips: away for days; nothing when there is too little to go on', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    expect(tips(store, today), isEmpty);
    store.reviews.add(r(today.subtract(const Duration(days: 4)), 'cards', false));
    final away = tips(store, today);
    expect(away.single.title, 'It has been 4 days since you practised');
  });

  test('trends: time of day, tiring in long sessions, memory and speed', () {
    final reviews = <Review>[];
    // Mornings: 30 answers, all right. Evenings: 30 answers, half right.
    for (var d = 0; d < 3; d++) {
      final morning = DateTime(2026, 11, 1 + d, 8);
      final evening = DateTime(2026, 11, 1 + d, 19);
      for (var i = 0; i < 10; i++) {
        reviews.add(r(morning.add(Duration(seconds: 20 * i)), 'meaning', true));
      }
      for (var i = 0; i < 10; i++) {
        reviews.add(r(evening.add(Duration(seconds: 20 * i)), 'meaning', i.isEven));
      }
    }
    // One long session: 60 answers, the last 25 all wrong.
    final long = DateTime(2026, 11, 8, 13);
    for (var i = 0; i < 60; i++) {
      reviews.add(r(long.add(Duration(minutes: i)), 'listen', i < 35));
    }
    // Flashcards: 20 two to four weeks ago at 50%, 20 lately at 90%, and faster.
    for (var i = 0; i < 20; i++) {
      reviews
        ..add(r(DateTime(2026, 10, 20, 12, i), 'cards', i.isEven, secs: 10))
        ..add(r(DateTime(2026, 10, 21, 12, i), 'meaning', true, secs: 10));
    }
    for (var i = 0; i < 20; i++) {
      reviews.add(r(DateTime(2026, 11, 9, 12, i), 'cards', i != 0, secs: 4));
    }
    reviews.sort((a, b) => a.at.compareTo(b.at));
    final titles = [for (final t in trends(reviews, today)) t.title];
    expect(titles, contains('You do best in the morning'));
    expect(titles, contains('You get less right late in long sessions'));
    expect(titles, contains('Your memory is getting better'));
    expect(titles, contains('You are answering faster'));
    expect(trends(reviews.take(10).toList(), today), isEmpty, reason: 'too few answers to say');
  });
}
