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

    test('opposite pairs are listed once each', () {
      final pairs = {
        for (final (a, b) in lib.opposites) ([a.simplified, b.simplified]..sort()).join('/'),
      };
      expect(pairs, contains((['大', '小']..sort()).join('/')));
      expect(pairs.length, lib.opposites.length);
    });

    test('words at levels switched off drop out of a scale', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final often = named('How often');
      expect(often.items.first.entry.simplified, '偶尔'); // HSK 5, off by default
      expect([for (final i in often.shown(store.shows)) i.entry.simplified], ['有时候', '常常', '总是']);
      final cold = lib.entries.firstWhere((e) => e.simplified == '冷');
      expect(scaleToOrder(lib, cold, store.shows)?.$1.name, 'Temperature');
      expect(scaleToOrder(lib, often.items.first.entry, store.shows), isNull);
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

    testWidgets('Library chip, scale screen, star all, word page card', (tester) async {
      final store = await open(tester);
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
    });
  });
}
