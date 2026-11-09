import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/daily.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/data/widget_feed.dart';
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
}
