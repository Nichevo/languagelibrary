import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/journey.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/models/journey_week.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  final now = DateTime(2026, 11, 18, 10); // a Wednesday
  final monday = DateTime(2026, 11, 16);

  /// A store that knows every HSK 1 word (cards back in three weeks).
  Future<UserStore> knowsHsk1() async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final strong = CardState(intervalDays: 25, ease: 2.5, due: now.add(const Duration(days: 20)), reps: 4);
    for (final e in lib.entries.where((e) => e.hsk == 1 && !e.isSentence)) {
      store.starred.add(e.id);
      store.cards['${e.id}:${Direction.values.first.name}'] = strong;
      store.firstKnown['${e.id}:${Direction.values.first.name}'] = now;
    }
    return store;
  }

  String zh(String id) => lib.byId[id]!.simplified;

  test('milestones and colours', () {
    expect(milestoneFor(0), 0);
    expect(milestoneFor(150), 1);
    expect(milestoneFor(899), 2);
    expect(milestoneFor(6000), 6);
    expect(milestoneColors.length, milestones.length + 1);
    expect(mondayOf(now), monday);
    expect(mondayOf(monday), monday);
  });

  test('suggestions link to known words and say why', () async {
    final store = await knowsHsk1();
    final c = Connections(lib, store);
    expect(c.known.length, greaterThan(400));
    final s = c.suggestions(limit: 40);
    expect(s, isNotEmpty);
    expect(s.every((x) => x.reasons.isNotEmpty), isTrue);
    expect(s.every((x) => !c.yours.contains(x.entry.id)), isTrue);
    final cook = c.score(lib.entries.firstWhere((e) => e.simplified == '做饭'));
    expect(cook.reasons.first, 'you know 做 + 饭');
    final almost = c.almostReadable(limit: 50);
    expect(almost, isNotEmpty);
    for (final a in almost) {
      expect(c.yours.contains(a.missing.id), isFalse);
    }
  });

  test('each path plans a week of new words', () async {
    final store = await knowsHsk1();
    for (final p in ['connections', 'topics', 'characters', 'sentences', 'hsk']) {
      final w = planWeek(lib, store, monday, p)!;
      expect(w.words, isNotEmpty, reason: p);
      expect(w.words.length, lessThanOrEqualTo(store.journeyPace), reason: p);
      expect(w.words.toSet().length, w.words.length, reason: p);
      // ignore: avoid_print
      print('$p: ${w.title} · ${w.words.map(zh).join(' ')}');
    }
    final grow = planWeek(lib, store, monday, 'connections', seed: lib.entries.firstWhere((e) => e.simplified == '小吃').id)!;
    expect(grow.title, 'Grows from 小吃');
    expect(grow.words.first, grow.seed);
  });

  test('paths take turns, with a review week every fourth week', () async {
    final store = await knowsHsk1();
    store.journeyPaths
      ..clear()
      ..addAll(['connections', 'topics']);
    final seen = <String>[];
    for (var i = 0; i < 5; i++) {
      seen.add(nextPath(store));
      store.weeks.add(JourneyWeek(start: monday.add(Duration(days: 7 * i)), path: seen.last, title: 't', why: '', words: [], skill: 'speak'));
    }
    expect(seen, ['connections', 'topics', 'connections', 'review', 'topics']);
  });

  test('ensureWeek starts the week once, and the picked week wins', () async {
    final store = await knowsHsk1();
    expect(await ensureWeek(lib, store, now), isFalse); // journey off
    await store.setJourneyOn(true);
    expect(await ensureWeek(lib, store, now), isTrue);
    expect(store.weekAt(now)!.start, monday);
    expect(await ensureWeek(lib, store, now), isFalse);
    final next = planWeek(lib, store, monday.add(const Duration(days: 7)), 'characters')!;
    await store.setNextWeek(next);
    final later = now.add(const Duration(days: 7));
    expect(await ensureWeek(lib, store, later), isTrue);
    expect(store.weekAt(later)!.title, next.title);
    expect(store.nextWeek, isNull);
  });

  test('found yourself: words first taken up in the week, outside its plan', () async {
    final store = await knowsHsk1();
    final w = lib.entries.firstWhere((e) => e.simplified == '小吃');
    await store.toggleStar(w.id);
    final found = foundBetween(lib, store, DateTime.now().subtract(const Duration(hours: 1)), DateTime.now().add(const Duration(hours: 1)));
    expect(found, [w.id]);
  });

  test('word web groups words by shared characters', () async {
    final store = await knowsHsk1();
    final web = wordWeb(Connections(lib, store));
    expect(web, isNotEmpty);
    expect(web.first.words.length, greaterThanOrEqualTo(web.last.words.length));
    for (final cl in web) {
      for (final id in cl.words) {
        expect(zh(id), contains(cl.hanzi));
      }
    }
  });

  test('weeks survive a save and a sync', () async {
    final store = await knowsHsk1();
    await store.setJourneyOn(true);
    await ensureWeek(lib, store, now);
    final json = store.exportBackup(now);
    SharedPreferences.setMockInitialValues({});
    final other = await UserStore.open();
    await other.mergeFrom(UserStore.backupData(json));
    expect(other.weeks.single.title, store.weeks.single.title);
    expect(other.journeyOn, isTrue);
  });
}
