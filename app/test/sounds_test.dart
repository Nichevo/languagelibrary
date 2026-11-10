import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/library.dart';
import 'package:language_library/data/sounds.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();

  test('tang has all four tones: 汤 糖 躺 烫', () {
    final tang = toneSets(lib).firstWhere((s) => s.syllable == 'tang');
    expect({for (final MapEntry(:key, :value) in tang.byTone.entries) key: value.simplified},
        {1: '汤', 2: '糖', 3: '躺', 4: '烫'});
    final ma = toneSets(lib).firstWhere((s) => s.syllable == 'ma');
    expect([for (final e in ma.words) e.simplified], ['妈', '麻', '马', '骂']);
  });

  test('tone sets: one syllable, one character, each tone different, four-tone sets first', () {
    final sets = toneSets(lib);
    expect(sets.where((s) => s.byTone.length == 4).length, greaterThan(20));
    var seenThree = false;
    for (final s in sets) {
      expect(s.byTone.length, greaterThanOrEqualTo(3));
      if (s.byTone.length == 3) seenThree = true;
      if (seenThree) expect(s.byTone.length, 3, reason: 'four-tone sets come first');
      for (final MapEntry(key: tone, value: e) in s.byTone.entries) {
        expect(e.simplified.runes.length, 1);
        expect(e.syllables.single.tone, tone);
        expect(e.pinyinNumbered.toLowerCase(), '${s.syllable}$tone');
      }
    }
    expect(toneSetFor(lib, lib.entries.firstWhere((e) => e.simplified == '糖'))?.syllable, 'tang');
  });

  test('same-sound groups are exactly alike, HSK 1 to 4', () {
    final groups = sameSounds(lib);
    expect(groups, isNotEmpty);
    final shi = groups.firstWhere((g) => g.pinyin == 'shì');
    expect(shi.words.map((e) => e.simplified), containsAll(['是', '事', '试']));
    for (final g in groups) {
      expect({for (final e in g.words) e.simplified}.length, greaterThanOrEqualTo(3));
      for (final e in g.words) {
        expect(e.pinyin, g.pinyin);
        expect(e.hsk, lessThanOrEqualTo(4));
      }
    }
  });

  test('one character, two sounds: 长 cháng and zhǎng', () {
    final chang = twoSounds(lib).firstWhere((t) => t.hanzi == '长');
    expect({for (final e in chang.readings) e.pinyin}, {'cháng', 'zhǎng'});
    for (final t in twoSounds(lib)) {
      expect({for (final e in t.readings) e.pinyinNumbered.toLowerCase()}.length, t.readings.length);
    }
  });

  test('tone rules list library words that carry the note', () {
    final rules = toneRules(lib);
    expect(rules.map((r) => r.note), contains('不 changes to bú before a 4th tone'));
    for (final r in rules) {
      expect(r.words, isNotEmpty);
      expect(r.words.length, lessThanOrEqualTo(8));
      for (final e in r.words) {
        expect(e.soundNotes, contains(r.note));
        expect(e.spoken, isNotNull);
      }
    }
  });

  test('tone questions: answer is in its set, never a two-reading character, no repeats in a row', () {
    final qs = toneQuestions(lib, Random(4), count: 40);
    expect(qs.length, 40);
    final twice = {for (final t in twoSounds(lib)) t.hanzi};
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      expect(q.set.words.map((e) => e.id), contains(q.answer.id));
      expect(twice, isNot(contains(q.answer.simplified)));
      if (i > 0) expect(q.answer.id, isNot(qs[i - 1].answer.id));
    }
    final tang = toneSets(lib).firstWhere((s) => s.syllable == 'tang');
    final only = toneQuestions(lib, Random(1), count: 8, only: tang);
    expect(only.every((q) => q.set == tang), isTrue);
  });

  screens();
}

Future<UserStore> _open(WidgetTester tester, Library lib) async {
  SharedPreferences.setMockInitialValues({});
  final store = await UserStore.open();
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(appForTest(lib, store));
  return store;
}

void screens() {
  final lib = loadRealLibrary();

  testWidgets('Library chip, a tone set, and its practice', (tester) async {
    final store = await _open(tester, lib);
    await tester.tap(find.text('Tricky sounds'));
    await tester.pumpAndSettle();
    expect(find.text('One sound, different tones'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'soup');
    await tester.pumpAndSettle();
    expect(find.text('汤'), findsWidgets);
    await tester.tap(find.text('汤').first);
    await tester.pumpAndSettle();
    expect(find.text('tang in 4 tones'), findsOneWidget);
    expect(find.text('1st tone: high and level'), findsOneWidget);
    await tester.tap(find.text('Practise'));
    await tester.pumpAndSettle();
    expect(find.text('Which one did you hear?'), findsOneWidget);
    await tester.tap(find.text('táng'));
    await tester.pumpAndSettle();
    expect(store.reviews.last.method, 'tones');
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('a word page shows its tone set', (tester) async {
    await _open(tester, lib);
    await tester.enterText(find.byType(TextField), 'sugar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('糖').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Same sound, other tones'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('烫'), findsOneWidget);
  });
}
