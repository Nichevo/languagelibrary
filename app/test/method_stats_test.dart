import 'package:flutter_test/flutter_test.dart';
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
}
