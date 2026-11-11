import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/families.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/patterns_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();

  Future<UserStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return UserStore.open();
  }

  test('families: every entry uses the character, biggest first, big enough', () async {
    final store = await fresh();
    final fams = families(lib, store.shows);
    expect(fams.length, greaterThan(20));
    for (var i = 0; i < fams.length; i++) {
      final f = fams[i];
      expect(f.size, greaterThanOrEqualTo(minFamily));
      if (i > 0) expect(f.size, lessThanOrEqualTo(fams[i - 1].size));
      for (final e in f.all) {
        expect(e.simplified, contains(f.hanzi));
        expect(store.shows(e), isTrue);
      }
      for (final h in f.heads) {
        expect(h.simplified, f.hanzi);
      }
      expect(f.words.every((e) => !e.isSentence), isTrue);
      expect(f.sentences.every((e) => e.isSentence), isTrue);
    }
    final zai = familyOf(lib, store.shows, '在')!;
    expect(zai.words.map((e) => e.simplified), contains('现在'));
    expect(zai.sentences.map((e) => e.simplified), contains('我在喝牛奶。'));
  });

  test('next to learn: the sentence you know most of, then the easiest word', () async {
    final store = await fresh();
    final zai = familyOf(lib, store.shows, '在')!;
    final first = nextToLearn(lib, zai, store)!;
    expect(first.of, 0, reason: 'nothing started yet, so a word');
    expect(first.entry.isSentence, isFalse);
    // Star the words of 我在喝牛奶。 except 在: that sentence comes next.
    final milk = lib.entries.firstWhere((e) => e.simplified == '我在喝牛奶。');
    for (final r in milk.related) {
      final w = lib.byId[r.id]!;
      if (w.simplified != '在') await store.toggleStar(w.id);
    }
    final next = nextToLearn(lib, zai, store)!;
    expect(next.entry.isSentence, isTrue);
    expect(next.known / next.of, greaterThanOrEqualTo(0.75));
  });

  test('patterns: chunks join to the sentence and the pinyin lines up', () {
    expect(lib.patterns.length, 8);
    for (final p in lib.patterns) {
      expect(p.examples.length, greaterThanOrEqualTo(3), reason: p.id);
      expect(p.sourceUrl, startsWith('https://resources.allsetlearning.com/chinese/grammar/'));
      for (final x in p.examples) {
        expect(x.zh.map((c) => c.text).join(), x.sentence.simplified);
        expect(x.en.map((c) => c.text).join(' '), x.sentence.meanings.first);
        expect(x.zhPinyin.join(' ').split(' ').where((s) => s.isNotEmpty).length, x.sentence.syllables.length);
        for (final c in [...x.zh, ...x.en]) {
          expect(roleLabels.keys, contains(c.role));
        }
      }
    }
    final milk = lib.patterns.firstWhere((p) => p.id == 'zai-now').examples.first;
    expect(milk.zhPinyin, ['wǒ', 'zài', 'hē niú nǎi']);
    expect(lib.patternsFor(milk.sentence).map((p) => p.id), contains('zai-now'));
  });

  test('build questions are never dealt in order', () {
    final rnd = Random(3);
    final qs = buildQuestions(lib, rnd, count: 100);
    expect(qs.length, lib.patterns.fold<int>(0, (n, p) => n + p.examples.length));
    for (final x in qs) {
      final o = shuffledOrder(x.zh, rnd);
      expect([for (final i in o) x.zh[i].text].join('|'), isNot(x.zh.map((c) => c.text).join('|')));
    }
  });

  testWidgets('Families chip and a family screen', (tester) async {
    final store = await fresh();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.dragUntilVisible(find.text('Families'), find.byType(ListView).first, const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Families'));
    await tester.pumpAndSettle();
    expect(find.textContaining('One character, many words'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '在');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('zài').first);
    await tester.pumpAndSettle();
    expect(find.text('The 在 family'), findsOneWidget);
    expect(find.text('Next to learn'), findsOneWidget);
    await tester.tap(find.textContaining('Star '));
    await tester.pumpAndSettle();
    expect(store.starred.length, familyOf(lib, store.shows, '在')!.words.length);
  });

  testWidgets('Patterns chip, a pattern, and building a sentence', (tester) async {
    final store = await fresh();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.dragUntilVisible(find.text('Patterns'), find.byType(ListView).first, const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patterns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doing it now: 在 + verb'));
    await tester.pumpAndSettle();
    expect(find.text('right now'), findsWidgets);
    expect(find.textContaining('Chinese Grammar Wiki'), findsWidgets);
    await tester.tap(find.text('Practise this'));
    await tester.pumpAndSettle();
    expect(find.text('Put it in Chinese order'), findsOneWidget);
    // Tap the chunks of whichever sentence came up, in the right order.
    final x = lib.patterns.firstWhere((p) => p.id == 'zai-now').examples.firstWhere(
        (x) => find.text(x.sentence.gloss).evaluate().isNotEmpty);
    for (final c in x.zh) {
      await tester.tap(find.widgetWithText(OutlinedButton, c.text));
      await tester.pump();
    }
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('All in order!'), findsOneWidget);
    expect(store.reviews.last.method, 'build');
    expect(store.reviews.last.rating, Rating.good);
  });
}
