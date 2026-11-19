import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/library.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/audio/speaker.dart';
import 'package:language_library/device/device.dart';
import 'package:language_library/main.dart';
import 'package:language_library/ui/common.dart';
import 'package:language_library/ui/drill_screen.dart';
import 'package:language_library/ui/scales_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  Scale named(String n) => lib.scales.firstWhere((s) => s.name == n);

  group('Scales data', () {
    test('scales load in order with their meanings', () {
      expect(lib.scales.length, greaterThanOrEqualTo(5));
      final t = named('Temperature');
      expect([for (final i in t.items) i.entry.simplified], ['冷', '凉快', '暖和', '热']);
      expect(t.items.last.meaning, 'hot (of weather)');
      expect(t.items[1].short, 'pleasantly cool');
      for (final s in lib.scales) {
        expect(s.items.length, greaterThanOrEqualTo(3), reason: s.name);
        for (final i in s.items) {
          expect(i.entry.meanings, contains(i.meaning), reason: '${s.name} ${i.entry.simplified}');
        }
      }
    });

    test('opposite pairs are listed once each, with their English', () {
      final pairs = {for (final p in lib.opposites) ([p.a.simplified, p.b.simplified]..sort()).join('/')};
      expect(pairs, contains((['大', '小']..sort()).join('/')));
      expect(pairs.length, lib.opposites.length);
      final big = lib.opposites.firstWhere((p) => {p.a.simplified, p.b.simplified}.containsAll(['大', '小']));
      expect(big.a.simplified == '大' ? big.aEnglish : big.bEnglish, 'big');
      expect(big.a.simplified == '大' ? big.bEnglish : big.aEnglish, 'small');
    });

    test('scales keep every word, whatever the level switches', () {
      final often = named('How often');
      expect(often.items.first.entry.simplified, '偶尔'); // HSK 5
      expect([for (final i in named('Size').items) i.entry.simplified], ['小', '中等', '大', '巨大']);
      final cold = lib.entries.firstWhere((e) => e.simplified == '冷');
      expect(scaleToOrder(lib, cold)?.$1.name, 'Temperature');
      expect(scaleToOrder(lib, lib.entries.firstWhere((e) => e.simplified == '书')), isNull);
    });

    test('"put in order" is only offered in the mix', () {
      expect(Choice.pickable, isNot(contains(Choice.order)));
      expect(Choice.fromSetting('order'), isNull);
      expect(Choice.fromSetting('pinyin'), Choice.pinyin);
    });

    test('a shuffled scale is never already in order', () {
      final items = named('Temperature').items;
      final rnd = Random(1);
      for (var n = 0; n < 50; n++) {
        expect(inScaleOrder(items, [for (final i in shuffledScale(items, rnd)) i.entry.id]), isFalse);
      }
      expect(inScaleOrder(items, [for (final i in items) i.entry.id]), isTrue);
    });
  });

  group('Scales screens', () {
    Future<UserStore> open(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appForTest(lib, store));
      return store;
    }

    testWidgets('Learn tab, scale screen, star all, word page card', (tester) async {
      final store = await open(tester);
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pairs & scales'));
      await tester.pumpAndSettle();
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Opposites'), findsOneWidget);

      await tester.tap(find.text('Temperature'));
      await tester.pumpAndSettle();
      expect(find.text('Play in order'), findsOneWidget);
      expect(find.text('hot (of weather)'), findsOneWidget);
      expect(find.text(scaleSourceNote), findsOneWidget);
      await tester.tap(find.text('Star all'));
      await tester.pumpAndSettle();
      expect(store.starred.length, 4);
      expect(find.text('All starred'), findsOneWidget);

      await tester.tap(find.text('冷').first);
      await tester.pumpAndSettle();
      expect(find.text('On a scale: Temperature'), findsOneWidget);
    });

    testWidgets('search narrows the scales', (tester) async {
      await open(tester);
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pairs & scales'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'yesterday');
      await tester.pumpAndSettle();
      expect(find.text('Days'), findsOneWidget);
      expect(find.text('Temperature'), findsNothing);
    });

    testWidgets('put a scale in order', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final t = named('Temperature');
      bool? result;
      await tester.pumpWidget(
        AppScope(
          library: lib,
          store: store,
          speaker: Speaker(lib),
          device: NoDevice(),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [OrderQuestion(scale: t, items: t.items, random: Random(2), onChecked: (r) => result = r)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap the words from cold to hot'), findsOneWidget);
      for (final i in t.items) {
        await tester.tap(find.widgetWithText(OutlinedButton, i.entry.simplified));
        await tester.pump();
      }
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('All in order!'), findsOneWidget);
      // Each place shows its word's pinyin and English, marked right.
      for (final i in t.items) {
        expect(find.text(i.entry.pinyin), findsWidgets);
        expect(find.text(i.short), findsWidgets);
      }
      expect(find.byIcon(Icons.check_circle), findsNWidgets(t.items.length));
      expect(find.text('Should be'), findsNothing);
    });

    testWidgets('drag mode: the choice is remembered and a shuffled order is wrong', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final t = named('Temperature');
      bool? result;
      await tester.pumpWidget(
        AppScope(
          library: lib,
          store: store,
          speaker: Speaker(lib),
          device: NoDevice(),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [OrderQuestion(scale: t, items: t.items, random: Random(2), onChecked: (r) => result = r)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drag'));
      await tester.pumpAndSettle();
      expect(store.orderByDrag, isTrue);
      expect(find.text('Drag the words from cold to hot'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
      // Checking straight away: shuffledScale never starts in the right order.
      // A wrong check does not end the question: it gives one hint.
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Hint 1'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
      // Showing the answer ends it, marked wrong, naming the right words.
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.textContaining('Here is the order.'), findsOneWidget);
      final wrong = tester.widgetList(find.byIcon(Icons.cancel)).length;
      expect(wrong, greaterThan(0));
      expect(find.text('Should be'), findsNWidgets(wrong));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(t.items.length - wrong));
      for (final i in t.items) {
        expect(find.text(i.entry.pinyin), findsWidgets);
        expect(find.text(i.short), findsWidgets);
      }
    });

    testWidgets('each wrong check keeps the right places and gives one hint', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final t = named('Days'); // 5 words
      final items = t.items;
      bool? result;
      await tester.pumpWidget(
        AppScope(
          library: lib,
          store: store,
          speaker: Speaker(lib),
          device: NoDevice(),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [OrderQuestion(scale: t, items: items, random: Random(2), onChecked: (r) => result = r)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapWord(int n) async {
        await tester.ensureVisible(find.widgetWithText(OutlinedButton, items[n].entry.simplified));
        await tester.tap(find.widgetWithText(OutlinedButton, items[n].entry.simplified));
        await tester.pump();
      }

      Future<void> check(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      // Right at the far end, back to front everywhere else: 明天 今天 昨天 前天 后天.
      for (final n in [3, 2, 1, 0, 4]) {
        await tapWord(n);
      }
      await check('Check');
      expect(result, isNull);
      // 后天 was right and stays, green with its English; hint 1 puts 前天 first.
      expect(find.text(items[4].short), findsWidgets);
      expect(find.text('Hint 1'), findsOneWidget);
      expect(find.textContaining('so it goes first.'), findsOneWidget);
      expect(find.text(items[0].short), findsWidgets);
      expect(find.text('2 of 5 in place. Tap the other 3 into order and check again.'), findsOneWidget);
      // The kept words can't be tapped again; the other three can.
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, items[0].entry.simplified)).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, items[4].entry.simplified)).onPressed, isNull);
      // Wrong again: 明天 今天 昨天 into places 2-4. Place 3 (今天) is right.
      for (final n in [3, 2, 1]) {
        await tapWord(n);
      }
      await check('Check again');
      // 今天 kept, hint 2 puts 昨天 in place 2, leaving one word: done.
      expect(find.text('Hint 2'), findsOneWidget);
      expect(find.textContaining('so it goes in place 2.'), findsOneWidget);
      expect(result, isFalse);
      expect(find.text('In order, with 2 hints. Tap a word to hear it.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
    });

    test('hint places read naturally', () {
      expect(scalePlace(0, 5), 'first');
      expect(scalePlace(2, 5), 'in place 3');
      expect(scalePlace(4, 5), 'last');
    });

    test('kept words stay in their places when others move', () {
      final items = named('Days').items;
      final moved = [items[4], items[3], items[2], items[1], items[0]];
      final pinned = pinLocked(items, {0, 2}, moved);
      expect(pinned[0], items[0]);
      expect(pinned[2], items[2]);
      expect([pinned[1], pinned[3], pinned[4]], [items[4], items[3], items[1]]);
    });
  });
}
