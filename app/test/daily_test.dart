import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/daily.dart';
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
}
