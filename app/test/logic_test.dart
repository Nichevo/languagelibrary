import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/library.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/models/entry.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Library loadRealLibrary() {
  final data = jsonDecode(File('assets/data/library.json').readAsStringSync()) as Map<String, dynamic>;
  return Library([for (final e in data['entries'] as List) Entry.fromJson(e as Map<String, dynamic>)]);
}

void main() {
  group('Scheduler', () {
    const s = Scheduler();
    final now = DateTime(2026, 11, 5, 9);

    test('new card intervals', () {
      expect(s.preview(null, Rating.again, now), '1 min');
      expect(s.preview(null, Rating.hard, now), '1 day');
      expect(s.preview(null, Rating.good, now), '1 day');
      expect(s.preview(null, Rating.easy, now), '3 days');
    });

    test('good answers space out, again resets', () {
      var c = s.review(null, Rating.good, now);
      expect(c.intervalDays, 1);
      c = s.review(c, Rating.good, now);
      expect(c.intervalDays, 3);
      c = s.review(c, Rating.good, now);
      expect(c.intervalDays, 8); // 3 x 2.5 rounded
      final lapsed = s.review(c, Rating.again, now);
      expect(lapsed.reps, 0);
      expect(lapsed.ease, lessThan(c.ease));
      expect(lapsed.due, now.add(const Duration(minutes: 1)));
    });

    test('ease never drops below the floor', () {
      CardState? c;
      for (var i = 0; i < 20; i++) {
        c = s.review(c, Rating.again, now);
      }
      expect(c!.ease, Scheduler.minEase);
    });

    test('due check', () {
      expect(s.isDue(null, now), isTrue);
      final c = s.review(null, Rating.good, now);
      expect(s.isDue(c, now), isFalse);
      expect(s.isDue(c, now.add(const Duration(days: 1))), isTrue);
    });

    test('state survives a save round trip', () {
      final c = s.review(null, Rating.easy, now);
      final back = CardState.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.due, c.due);
      expect(back.ease, c.ease);
    });
  });

  group('Library data', () {
    final lib = loadRealLibrary();

    test('starter set is a sensible size and every entry is complete', () {
      expect(lib.entries.length, inInclusiveRange(400, 800));
      for (final e in lib.entries) {
        expect(e.meanings, isNotEmpty, reason: e.simplified);
        expect(e.syllables, isNotEmpty, reason: e.simplified);
        expect(e.sources, contains('CC-CEDICT'), reason: e.simplified);
      }
    });

    test('ids are unique', () {
      expect(lib.byId.length, lib.entries.length);
    });

    test('search by hanzi, pinyin and English', () {
      expect(lib.search('你好').first.simplified, '你好');
      expect(lib.search('nihao').first.simplified, '你好');
      expect(lib.search('ni3 hao3').first.simplified, '你好');
      expect(lib.search('nǐ hǎo').first.simplified, '你好');
      expect(lib.search('thank you').map((e) => e.simplified), contains('谢谢'));
    });

    test('topic filter', () {
      final food = lib.search('', topic: 'food');
      expect(food, isNotEmpty);
      expect(food.every((e) => e.topics.contains('food')), isTrue);
      expect(lib.search('', topic: 'numbers').map((e) => e.simplified), containsAll(['一', '二', '十']));
    expect(lib.search('', topic: 'love').map((e) => e.simplified), containsAll(['漂亮', '可爱', '怎么样', '晚安']));
    expect(lib.search('', topic: 'food').map((e) => e.simplified), containsAll(['咖啡', '拿铁']));
    });

    test('tone change note for 你好', () {
      final e = lib.search('你好').first;
      expect(e.spoken, 'ní hǎo');
    });
  });

  group('Practice queue', () {
    late UserStore store;
    final lib = loadRealLibrary();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await UserStore.open();
    });

    test('each starred word gives two cards, Chinese to English first', () async {
      final words = lib.search('').take(3).toList();
      for (final w in words) {
        await store.toggleStar(w.id);
      }
      final q = buildQueue(entries: words, store: store, now: DateTime.now());
      expect(q.length, 6);
      expect(q.take(3).every((c) => c.direction == Direction.zhToEn), isTrue);
    });

    test('reviewed cards drop out until due', () async {
      final w = lib.entries.first;
      final now = DateTime(2026, 11, 5, 9);
      await store.saveCard(w.id, Direction.zhToEn, const Scheduler().review(null, Rating.good, now));
      final q = buildQueue(entries: [w], store: store, now: now);
      expect(q.map((c) => c.direction), [Direction.enToZh]);
    });

    test('lists and stars persist', () async {
      final w = lib.entries.first;
      await store.createList('Restaurant');
      await store.setInList('Restaurant', w.id, true);
      final again = await UserStore.open();
      expect(again.isStarred(w.id), isTrue);
      expect(again.idsIn('Restaurant'), [w.id]);
      await again.toggleStar(w.id);
      expect(again.idsIn('Restaurant'), isEmpty);
    });
  });
}
