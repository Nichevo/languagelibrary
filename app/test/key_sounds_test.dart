import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/key_sounds.dart';
import 'package:language_library/data/library.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/speech/pitch.dart';
import 'package:language_library/speech/recognizer.dart';
import 'package:language_library/speech/speech_service.dart';
import 'package:language_library/ui/say_both_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Library loadWithSounds() {
  final data = jsonDecode(File('assets/data/library.json').readAsStringSync()) as Map<String, dynamic>;
  final ks = KeySounds.fromJson(jsonDecode(File('assets/data/sound_pairs.json').readAsStringSync()) as Map<String, dynamic>);
  return Library.fromJson(data, keySounds: ks);
}

SoundTry t(String contrast, bool right, [int minute = 0]) =>
    SoundTry(DateTime(2026, 11, 19, 9, minute), contrast, 'a', right ? 'a' : 'b');

void main() {
  final lib = loadWithSounds();
  final ks = lib.keySounds;

  test('the pairs file: five groups, and 是 shì / 四 sì is a sh/s pair', () {
    expect([for (final g in ks.groups) g.id], ['tones', 'hiss', 'puff', 'u', 'nng']);
    final shs = ks.shown(lib, (_) => true, contrast: 'hiss:sh/s');
    expect(shs.any((p) => p.a.simplified == '是' && p.b.simplified == '四'), isTrue);
    for (final p in ks.shown(lib, (_) => true)) {
      expect(p.a.syllables.length, 1);
      expect(p.a.id == p.b.id, isFalse);
    }
    expect(ks.group('tones')!.heardCheck, isFalse, reason: 'the recogniser is not good enough on tones');
  });

  test('level switches hide pairs whose words are all switched off', () {
    final all = ks.shown(lib, (_) => true).length;
    final easy = ks.shown(lib, (e) => (e.hsk ?? 9) <= 2).length;
    expect(easy, lessThan(all));
    expect(easy, greaterThan(50));
  });

  test('trouble sounds: at least 6 tries, under 75% right, until 8 right in a row', () {
    final tries = [
      for (var i = 0; i < 6; i++) t('hiss:sh/s', i.isEven, i),
      for (var i = 0; i < 5; i++) t('nng:an/ang', false, i),
      for (var i = 0; i < 10; i++) t('puff:b/p', i > 1, i),
    ];
    expect(troubleSounds(tries), ['hiss:sh/s'], reason: 'an/ang has only 5 tries; b/p is 8 of 10');
    final cleared = [...tries, for (var i = 0; i < 8; i++) t('hiss:sh/s', true, 30 + i)];
    final s = contrastScores(cleared)['hiss:sh/s']!;
    expect(s.runOfRight, 8);
    expect(troubleSounds(cleared), isEmpty);
  });

  test('only the last 20 tries count', () {
    final tries = [for (var i = 0; i < 30; i++) t('tones:2/3', i >= 10, i)];
    final s = contrastScores(tries)['tones:2/3']!;
    expect((s.right, s.total), (20, 20));
  });

  test('questions: about 7 in 10 from trouble sounds, never the same pair twice in a row', () {
    final pool = ks.shown(lib, (_) => true);
    final qs = soundQuestions(pool, Random(3), count: 200, trouble: ['hiss:sh/s']);
    final hard = qs.where((q) => q.pair.pair.contrast == 'hiss:sh/s').length;
    expect(hard, inInclusiveRange(110, 170));
    for (var i = 1; i < qs.length; i++) {
      expect(identical(qs[i].pair, qs[i - 1].pair), isFalse);
    }
  });

  test('the part that differs', () {
    expect(differingPart('bái', 'bǎi'), (1, 2));
    expect(differingPart('wǎn', 'wǎng'), (3, 3));
  });

  test('sound tries are saved and merged from another device', () async {
    SharedPreferences.setMockInitialValues({});
    final phone = await UserStore.open();
    await phone.logSoundTry(t('hiss:sh/s', false));
    SharedPreferences.setMockInitialValues({});
    final ipad = await UserStore.open();
    await ipad.mergeFrom(UserStore.backupData(phone.exportBackup(DateTime(2026, 11, 19))));
    await ipad.mergeFrom(UserStore.backupData(phone.exportBackup(DateTime(2026, 11, 19))));
    expect(ipad.soundTries.length, 1);
    expect(ipad.soundTries.single.right, isFalse);
  });

  final tones = <String, List<String>>{'四': ['si4'], '是': ['shi4'], '事': ['shi4'], '八': ['ba1'], '拔': ['ba2'], '绿': ['lu4', 'lü4']};

  test('which side the recogniser heard', () {
    expect(heardSide('四', 'shi4', 'si4', 'initial', tones), 'b');
    expect(heardSide('事', 'shi4', 'si4', 'initial', tones), 'a', reason: 'same sound, another character');
    expect(heardSide('八', 'ba1', 'ba2', 'tone', tones), 'a');
    expect(heardSide('', 'shi4', 'si4', 'initial', tones), isNull);
    expect(heardSide('绿', 'lü4', 'lu4', 'final', tones), isNull, reason: '绿 reads both ways');
  });

  test('a Say it slip names its contrast', () {
    final shi = lib.entries.firstWhere((e) => e.simplified == '是' && e.syllables.length == 1);
    expect(slipContrast(shi, '四', lib, tones), 'hiss:sh/s');
    expect(slipContrast(shi, '是', lib, tones), isNull);
    expect(pairsFor(shi, lib, (_) => true).any((p) => p.b.simplified == '四' && p.a.id == shi.id), isTrue);
  });

  test('say slips are saved and merged', () async {
    SharedPreferences.setMockInitialValues({});
    final phone = await UserStore.open();
    await phone.logSaySlip(SaySlip(DateTime(2026, 11, 19, 9), 'hiss:sh/s', 'x', '四'));
    SharedPreferences.setMockInitialValues({});
    final ipad = await UserStore.open();
    await ipad.mergeFrom(UserStore.backupData(phone.exportBackup(DateTime(2026, 11, 19))));
    await ipad.mergeFrom(UserStore.backupData(phone.exportBackup(DateTime(2026, 11, 19))));
    expect(ipad.saySlips.single.heard, '四');
    expect(slipCounts(ipad.saySlips, DateTime(2026, 11, 18)).single.value, 1);
  });

  testWidgets('Say both: heard the other word, logged as a slip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pair = lib.keySounds.shown(lib, (_) => true, contrast: 'hiss:sh/s').firstWhere((p) => p.a.simplified == '是');
    final checker = _Checker('四');
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => SayBothScreen(pair: pair, recorder: _Recorder(), checker: checker)));
    await tester.pumpAndSettle();
    final mic = find.byIcon(Icons.mic).first;
    final g = await tester.startGesture(tester.getCenter(mic));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));
    await g.up();
    // Let the (real) asset loading finish.
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty || i == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Sounded closer to 四'), findsOneWidget);
    expect(store.saySlips.single.contrast, 'hiss:sh/s');
  });

  testWidgets('a word page shows what it sounds like', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'four');
    await tester.pumpAndSettle();
    await tester.tap(find.text('四').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sounds like'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('是 shì · sh / s'), findsOneWidget);
  });

  testWidgets('Practice > Key sounds > a group > one round', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Key sounds'));
    await tester.pumpAndSettle();
    expect(find.text('Your trouble sounds'), findsOneWidget);
    await tester.tap(find.text('zh ch sh · z c s · j q x'));
    await tester.pumpAndSettle();
    expect(find.text('How to tell them apart'), findsOneWidget);
    await tester.tap(find.text('Practise this group'));
    await tester.pumpAndSettle();
    expect(find.text('Which one did you hear?'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 44).first);
    await tester.pumpAndSettle();
    expect(store.reviews.last.method, 'tones');
    expect(store.soundTries.single.contrast, startsWith('hiss:'));
    expect(find.text('Hear both'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}

class _Recorder implements Recorder {
  @override
  Future<bool> allowed() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<String?> stop() async => 'fake.wav';
  @override
  Future<void> dispose() async {}
}

class _Checker implements SpeechChecker {
  _Checker(this.text);
  String text;
  @override
  Future<SpeechResult> analyse(String wavPath) async => SpeechResult(Transcript(text, null), PitchTrack(const []));
}
