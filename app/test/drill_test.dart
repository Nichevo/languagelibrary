import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/models/entry.dart';
import 'package:language_library/ui/drill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();
  final nihao = lib.entries.firstWhere((e) => e.simplified == '你好');
  final de = lib.entries.firstWhere((e) => e.simplified == '的' && e.pinyinNumbered == 'de5');

  test('typed pinyin: marks or numbers, spaces optional, neutral tone optional', () {
    expect(checkPinyin('nǐ hǎo', nihao), PinyinCheck.right);
    expect(checkPinyin('ni3hao3', nihao), PinyinCheck.right);
    expect(checkPinyin('Ni3 Hao3', nihao), PinyinCheck.right);
    expect(checkPinyin('ni2 hao3', nihao), PinyinCheck.wrongTones);
    expect(checkPinyin('nihao', nihao), PinyinCheck.wrongTones);
    expect(checkPinyin('ni hao ma', nihao), PinyinCheck.wrong);
    expect(checkPinyin('', nihao), PinyinCheck.wrong);
    expect(checkPinyin('de', de), PinyinCheck.right);
    expect(checkPinyin('de5', de), PinyinCheck.right);
    final nv = lib.entries.firstWhere((e) => e.simplified == '女');
    expect(checkPinyin('nv3', nv), PinyinCheck.right);
    expect(checkPinyin('nǚ', nv), PinyinCheck.right);
  });

  test('listening choices never sound the same as the answer', () {
    final rnd = Random(4);
    for (final target in lib.entries.where((e) => !e.isSentence).take(50)) {
      final others = distractors(target, lib.entries, 3, rnd);
      expect(others.length, 3);
      String sound(e) => stripTones(normalizePinyin(e.pinyin));
      expect(others.every((e) => !e.isSentence && e.id != target.id && sound(e) != sound(target)), isTrue);
      expect({for (final e in others) sound(e)}.length, 3);
    }
  });

  testWidgets('type the pinyin, then listen and pick', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await store.toggleStar(nihao.id);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));

    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    expect(store.practiceMode, 'type');
    await tester.tap(find.text('All starred words'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ni3 hao3');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Right!'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 1 right'), findsOneWidget);
    expect(store.reviews.length, 1);
    expect(store.cards, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All starred words'));
    await tester.pumpAndSettle();
    expect(find.text('Which word did you hear?'), findsOneWidget);
    await tester.tap(find.text('你好'));
    await tester.pumpAndSettle();
    expect(find.text('Right!'), findsOneWidget);
    expect(store.reviews.length, 2);
  });
}
