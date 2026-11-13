import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/daily.dart';
import 'package:language_library/data/storage.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();

  test('word of the day: same all day, changes daily, never a sentence', () {
    final morning = wordOfTheDay(lib, DateTime(2026, 11, 5, 7))!;
    expect(wordOfTheDay(lib, DateTime(2026, 11, 5, 23, 59))!.id, morning.id);
    final month = {for (var d = 1; d <= 30; d++) wordOfTheDay(lib, DateTime(2026, 11, d))!.id};
    expect(month.length, 30);
    for (var d = 0; d < 400; d++) {
      expect(wordOfTheDay(lib, DateTime(2026).add(Duration(days: d)))!.isSentence, isFalse);
    }
  });

  test('cards due by day, for the reminder and the widget', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final now = DateTime(2026, 11, 5, 9);
    expect(dueByDay(store, now, days: 3).map((d) => d.$2), [0, 0, 0]);
    final a = lib.entries[0].id, b = lib.entries[1].id;
    await store.toggleStar(a);
    await store.toggleStar(b);
    // b's two cards were studied: one due in two days, one in a week.
    CardState due(int days) =>
        CardState(reps: 1, intervalDays: days.toDouble(), ease: 2.5, due: now.add(Duration(days: days)), lapses: 0);
    await store.saveCard(b, Direction.zhToEn, due(2));
    await store.saveCard(b, Direction.enToZh, due(7));
    final counts = dueByDay(store, now, days: 8).map((d) => d.$2).toList();
    expect(counts, [2, 2, 3, 3, 3, 3, 3, 4]);
  });

  test('days count on through daylight saving changes (run with TZ=Europe/London to check)', () {
    for (final (y, m, d) in [(2026, 3, 29), (2026, 10, 25), (2026, 11, 1)]) {
      final before = DateTime(y, m, d - 1, 12), on = DateTime(y, m, d, 12), after = DateTime(y, m, d + 1, 12);
      expect(dayNumber(on) - dayNumber(before), 1);
      expect(dayNumber(after) - dayNumber(on), 1);
      expect(dayPlus(DateTime(y, m, d - 1), 1), DateTime(y, m, d));
      expect(dayKey(dayPlus(DateTime(y, m, d), 1)), dayKey(after));
      expect(wordOfTheDay(lib, on)!.id, isNot(wordOfTheDay(lib, before)!.id));
    }
  });

  test('cards due now count starred words only', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final now = DateTime(2026, 11, 5, 9);
    final a = lib.entries[0].id, b = lib.entries[1].id;
    final past = CardState(reps: 1, intervalDays: 1, ease: 2.5, due: now.subtract(const Duration(hours: 1)), lapses: 0);
    await store.toggleStar(a);
    await store.toggleStar(b);
    await store.saveCard(a, Direction.zhToEn, past);
    await store.saveCard(b, Direction.zhToEn, past);
    expect(dueNow(store, now), 2);
    await store.toggleStar(b); // unstarred: its card is kept but not due for practice
    expect(dueNow(store, now), 1);
  });

  test('tone digits line up with characters, 0 for punctuation', () {
    final hao = lib.entries.firstWhere((e) => e.simplified == '你好');
    expect(toneDigits(hao), '33');
    final s = lib.entries.firstWhere((e) => e.simplified == '我要一杯咖啡。');
    expect(toneDigits(s), '3411110');
  });

  test('backup and restore keep everything, and a bad file changes nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final id = lib.entries[3].id;
    await store.toggleStar(id);
    await store.createList('Cafe');
    await store.setInList('Cafe', id, true);
    await store.setDifficulty(id, Difficulty.hard);
    await store.setReminder(on: true, minutes: 7 * 60 + 30);
    final backup = store.exportBackup(DateTime(2026, 11, 5));

    SharedPreferences.setMockInitialValues({});
    final fresh = await UserStore.open();
    await fresh.toggleStar(lib.entries[9].id);
    await expectLater(fresh.importBackup('{"hello": 1}'), throwsFormatException);
    await expectLater(fresh.importBackup('not json'), throwsFormatException);
    expect(fresh.starred, [lib.entries[9].id]);

    await fresh.importBackup(backup);
    expect(fresh.starred, [id]);
    expect(fresh.lists['Cafe'], [id]);
    expect(fresh.difficulty[id], Difficulty.hard);
    expect(fresh.reminderMinutes, 7 * 60 + 30);
    final again = await UserStore.open();
    expect(again.starred, [id]);
  });

  test('storage use adds up each part of the library', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final parts = await libraryStorage();
    final byName = {for (final p in parts) p.label: p};
    expect(byName.keys, containsAll(['Words and phrases', 'Phrasebook sentences', 'Example sentences', 'Recorded audio']));
    final libraryFile = File('assets/data/library.json').lengthSync();
    final split = ['Words and phrases', 'Phrasebook sentences', 'Example sentences']
        .fold<int>(0, (n, k) => n + byName[k]!.bytes);
    expect((split - libraryFile).abs(), lessThan(5));
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
  });
}
