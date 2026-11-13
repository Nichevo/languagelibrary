import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/audio/speaker.dart';
import 'package:language_library/data/say_it.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/device/device.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/ui/common.dart';
import 'package:language_library/models/entry.dart';
import 'package:language_library/speech/feedback.dart';
import 'package:language_library/speech/heard.dart';
import 'package:language_library/speech/pitch.dart';
import 'package:language_library/speech/recognizer.dart';
import 'package:language_library/speech/speech_service.dart';
import 'package:language_library/speech/tone_shape.dart';
import 'package:language_library/speech/wav.dart';
import 'package:language_library/ui/say_it_screen.dart';
import 'package:language_library/ui/say_it_words_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

/// A 16-bit mono WAV file of [samples].
Uint8List wavOf(List<double> samples, {int rate = 16000}) {
  final b = ByteData(44 + samples.length * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + samples.length * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, (samples[i] * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// A voice-like tone whose pitch moves from [fromHz] to [toHz].
List<double> glide(double fromHz, double toHz, {double seconds = 0.5}) {
  final n = (16000 * seconds).round();
  var phase = 0.0;
  return [
    for (var i = 0; i < n; i++)
      () {
        final f = fromHz + (toHz - fromHz) * i / n;
        phase += 2 * pi * f / 16000;
        // A few harmonics, like a voice.
        return 0.5 * sin(phase) + 0.25 * sin(2 * phase) + 0.1 * sin(3 * phase);
      }(),
  ];
}

void main() {
  final lib = loadRealLibrary();
  final tones = CharTones.parse(File('assets/data/char_tones.tsv').readAsStringSync());
  Entry word(String hanzi) => lib.entries.firstWhere((e) => e.simplified == hanzi);

  group('what the recogniser heard', () {
    test('tone marks', () {
      expect(markTone('jian4'), 'jiàn');
      expect(markTone('mai3'), 'mǎi');
      expect(markTone('nü3'), 'nǚ');
      expect(markTone('gou3'), 'gǒu');
      expect(markTone('gui4'), 'guì');
      expect(markTone('liu2'), 'liú');
      expect(markTone('ma5'), 'ma');
    });

    test('the same characters are right', () {
      final c = checkHeard(word('谢谢'), '谢谢', tones);
      expect(c.allRight, isTrue);
      expect(verdictOf(c), Verdict.matched);
      expect(problems(c), isEmpty);
    });

    test('a character with the same sound and tone is right: 见 for 件', () {
      expect(checkHeard(word('件'), '见', tones).allRight, isTrue);
    });

    test('same sound, other tone: 卖 mài for 买 mǎi', () {
      final c = checkHeard(word('买'), '卖', tones);
      final s = c.syllables.single;
      expect(s.heard, Heard.tone);
      expect(s.char, '卖');
      expect(s.reading, 'mài');
      expect(problems(c).single, '买 mǎi came out as 卖 mài, a 4th tone. Aim for the 3rd tone: low, dipping.');
    });

    test('a different sound in a sentence: 是 for 吃', () {
      final e = lib.entries.firstWhere((e) => e.isSentence && e.simplified.contains('吃') && e.simplified.length <= 8);
      final heard = e.simplified.replaceFirst('吃', '是');
      final c = checkHeard(e, heard, tones);
      final bad = c.syllables.where((s) => s.heard != Heard.right).toList();
      expect(bad.single.syllable.hanzi, '吃');
      expect(bad.single.heard, Heard.sound);
      expect(bad.single.reading, 'shì');
      expect(verdictOf(c), Verdict.close);
    });

    test('a tone change counts: 不 said bú in 不客气', () {
      expect(checkHeard(word('不客气'), '不客气', tones).allRight, isTrue);
    });

    test('a dropped 儿 is fine, a dropped syllable is not', () {
      final erhua = lib.entries.firstWhere((e) => e.simplified == '一点儿');
      expect(checkHeard(erhua, '一点', tones).allRight, isTrue);
      final c = checkHeard(word('不客气'), '客气', tones);
      expect(c.syllables.first.heard, Heard.missed);
      expect(problems(c).single, 'It didn\'t hear 不 bù.');
    });

    test('extra characters and nothing at all', () {
      final c = checkHeard(word('谢谢'), '谢谢你', tones);
      expect(c.extra, ['你']);
      expect(c.allRight, isFalse);
      final none = checkHeard(word('谢谢'), '', tones);
      expect(none.heardNothing, isTrue);
      expect(verdictOf(none), Verdict.nothing);
      expect(none.syllables.every((s) => s.heard == Heard.missed), isTrue);
    });

    test('char_tones.tsv has readings with tones', () {
      expect(tones.byChar['买'], ['mai3']);
      expect(tones.byChar['了'], containsAll(['le5', 'liao3']));
      expect(tones.byChar.length, greaterThan(8000));
    });
  });

  group('pitch', () {
    test('reads back a WAV file', () {
      final s = readWav(wavOf([0, 0.5, -0.5, 0.25]));
      expect(s.sampleRate, 16000);
      expect(s.data.length, 4);
      expect(s.data[1], closeTo(0.5, 0.001));
      expect(s.data[2], closeTo(-0.5, 0.001));
      expect(() => readWav(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });

    test('finds a steady pitch', () {
      final t = trackPitch(readWav(wavOf(glide(200, 200))));
      expect(t.median, closeTo(200, 3));
    });

    test('a rising tone rises and a falling tone falls', () {
      List<double> line(double a, double b) {
        final st = trackPitch(readWav(wavOf([...List.filled(1600, 0.0), ...glide(a, b), ...List.filled(1600, 0.0)])))
            .semitones
            .nonNulls
            .toList();
        return [st.first, st.last];
      }

      final up = line(150, 250);
      expect(up.last - up.first, greaterThan(6)); // 150 to 250 Hz is about 9 semitones
      final down = line(300, 150);
      expect(down.first - down.last, greaterThan(9));
    });

    test('silence has no pitch and nothing to draw', () {
      final t = trackPitch(readWav(wavOf(List.filled(8000, 0.0))));
      expect(t.median, isNull);
      expect(PitchPicture.of(t).isEmpty, isTrue);
    });

    test('voiced stretches bridge short breaks and drop blips', () {
      final hz = <double?>[
        ...List.filled(10, 200.0), null, null, ...List.filled(10, 200.0), // one stretch
        ...List.filled(8, null), ...List.filled(10, 180.0), // a second
        ...List.filled(8, null), 150.0, 150.0, // a blip
      ];
      expect(voicedRuns(hz), [(0, 22), (30, 40)]);
    });
  });

  test('a round puts starred words first and keeps words and sentences apart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final star = word('买');
    await store.toggleStar(star.id);
    final words = sayItQueue(lib, store, Random(1), sentences: false, count: 10);
    expect(words.first.id, star.id);
    expect(words.length, 10);
    expect(words.every((e) => !e.isSentence && e.simplified.length <= 4), isTrue);
    final sentences = sayItQueue(lib, store, Random(1), sentences: true, count: 5);
    expect(sentences.every((e) => e.isSentence), isTrue);
  });

  group('tries per word', () {
    SpeakTry t(String id, bool ok, int minute) => SpeakTry(DateTime(2026, 11, 13, 9, minute), id, ok);

    test('rounds run until the first success', () {
      final r = speakRecords([t('a', false, 0), t('a', true, 1), t('a', true, 2), t('a', false, 3)])['a']!;
      expect(r.rounds, [2, 1]);
      expect(r.open, 1);
      expect(r.tries, 4);
      expect(r.average, 2); // (2 + 1 + 1 open) / 2
      expect(r.level, SpeakLevel.gettingThere);
    });

    test('levels', () {
      SpeakLevel? level(List<bool> tries) =>
          speakRecords([for (var i = 0; i < tries.length; i++) t('a', tries[i], i)])['a']!.level;
      expect(level([true]), SpeakLevel.easy);
      expect(level([true, true, false, true, true]), SpeakLevel.easy);
      expect(level([true, true, false, true]), SpeakLevel.gettingThere, reason: 'the last one took two tries');
      expect(level([false]), isNull);
      expect(level([false, false, false]), SpeakLevel.struggling);
      expect(level([false, false, true]), SpeakLevel.struggling);
      expect(level([false, true]), SpeakLevel.gettingThere);
      expect(level([true, false, true]), SpeakLevel.gettingThere);
    });

    test('kept in backups and joined by sync', () async {
      SharedPreferences.setMockInitialValues({});
      final phone = await UserStore.open();
      await phone.logSpeakTry('a', false, DateTime(2026, 11, 13, 9));
      await phone.logSpeakTry('a', true, DateTime(2026, 11, 13, 10));
      final data = UserStore.backupData(phone.exportBackup(DateTime(2026, 11, 13)));
      SharedPreferences.setMockInitialValues({});
      final ipad = await UserStore.open();
      await ipad.logSpeakTry('a', false, DateTime(2026, 11, 13, 9, 30));
      await ipad.mergeFrom(data);
      await ipad.mergeFrom(data);
      expect(ipad.speakTries.map((x) => (x.at.hour, x.at.minute, x.right)),
          [(9, 0, false), (9, 30, false), (10, 0, true)]);
      expect(speakRecords(ipad.speakTries)['a']!.rounds, [3]);
    });
  });

  test('a sentence splits into library words, read the way the sentence reads them', () {
    final s = lib.entries.firstWhere((e) => e.isSentence && e.simplified == '有谁想一起去吃饭吗？');
    final words = [for (final (_, w) in wordsIn(s, lib)) w];
    expect(words.map((w) => w.simplified), containsAllInOrder(['有', '谁', '想', '一起', '去', '吃饭', '吗']));
    // 谁 is read shéi here, so the shéi entry is the one used, not shuí.
    expect(words.firstWhere((w) => w.simplified == '谁').pinyin, 'shéi');
  });

  test('the on-device recogniser hears the app\'s own 谢谢 clip', () {
    final Recognizer r;
    try {
      // Where pub put the Linux build of the recogniser's native library.
      final config = File('.dart_tool/package_config.json').readAsStringSync();
      final root = RegExp(r'"rootUri":\s*"([^"]*sherpa_onnx_linux[^"]*)"').firstMatch(config)!.group(1)!;
      final dir = Uri.parse(root.endsWith('/') ? root : '$root/').resolve('linux/x64').toFilePath();
      r = Recognizer(const ModelFiles('assets/speech/model.int8.onnx', 'assets/speech/tokens.txt'), libraryPath: dir);
    } catch (e) {
      markTestSkipped('speech recogniser library not available here: $e');
      return;
    }
    final result = analyseWav(File('test/fixtures/xiexie.wav').readAsBytesSync(), r);
    expect(result.transcript.text, '谢谢');
    expect(result.transcript.charTimes, hasLength(2));
    expect(result.pitch.median, isNotNull);
    expect(checkHeard(word('谢谢'), result.transcript.text, tones).allRight, isTrue);
    final b = analyseWav(File('test/fixtures/bukeqi.wav').readAsBytesSync(), r);
    expect(checkHeard(word('不客气'), b.transcript.text, tones).allRight, isTrue);
    r.free();
  });

  group('Say it screen', () {
    Future<UserStore> pumpScreen(WidgetTester tester, SpeechChecker checker, List<Entry> entries) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      await tester.pumpWidget(AppScope(
        library: lib,
        store: store,
        speaker: Speaker(lib),
        device: NoDevice(),
        child: MaterialApp(home: SayItScreen(entries: entries, recorder: _FakeRecorder(), checker: checker)),
      ));
      await tester.pumpAndSettle();
      return store;
    }

    Future<void> speak(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));
      await gesture.up();
      // Let the (real) asset loading finish.
      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty || i == 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a match is shown and logged once', (tester) async {
      final store = await pumpScreen(tester, _FakeChecker('谢谢'), [word('谢谢')]);
      expect(find.text('Hold to speak, let go to check'), findsOneWidget);
      await speak(tester);
      expect(find.text('It heard 谢谢'), findsOneWidget);
      expect(find.text('YOUR PITCH'), findsOneWidget);
      expect(store.reviews.where((r) => r.method == 'speak'), hasLength(1));
      expect(store.reviews.last.rating, Rating.good);
      await speak(tester);
      expect(store.reviews.where((r) => r.method == 'speak'), hasLength(1), reason: 'only the first try counts');
    });

    testWidgets('a wrong tone is explained', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(tester, _FakeChecker('卖'), [word('买')]);
      await speak(tester);
      expect(find.text('It heard 卖'), findsOneWidget);
      expect(find.text('买 mǎi came out as 卖 mài, a 4th tone. Aim for the 3rd tone: low, dipping.'), findsOneWidget);
    });

    testWidgets('buttons sit above the mic, and tries are counted until it is right', (tester) async {
      final checker = _FakeChecker('卖');
      final store = await pumpScreen(tester, checker, [word('买'), word('谢谢')]);
      final mic = tester.getCenter(find.byIcon(Icons.mic)).dy;
      for (final label in ['Listen', 'Play mine', 'Skip']) {
        expect(tester.getCenter(find.text(label)).dy, lessThan(mic), reason: '$label is above the mic');
      }
      await speak(tester);
      expect(find.text('Try 1 at this one'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      await speak(tester);
      expect(find.text('Try 2 at this one so far'), findsOneWidget);
      checker.text = '买';
      await speak(tester);
      expect(find.text('Got it in 3 tries'), findsOneWidget);
      expect(store.speakTries.map((t) => t.right), [false, false, true]);
      expect(store.reviews.where((r) => r.method == 'speak'), hasLength(1), reason: 'one answer per word per round');
      final r = speakRecords(store.speakTries)[word('买').id]!;
      expect(r.rounds, [3]);
      expect(r.level, SpeakLevel.struggling);
    });

    testWidgets('one word of a sentence can be practised on its own', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sentence = lib.entries.firstWhere((e) => e.isSentence && e.simplified == '咱们去吃饭吧。');
      await pumpScreen(tester, _FakeChecker(sentence.simplified.replaceFirst('吃', '是')), [sentence]);
      await speak(tester);
      expect(find.text('PRACTISE ONE WORD'), findsOneWidget);
      final chip = find.widgetWithText(ActionChip, '吃饭 chī fàn');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(SayItScreen, skipOffstage: false), findsNWidgets(2));
      // The new screen is just the word, ready to listen to and say.
      expect(find.text('chī fàn'), findsWidgets);
      expect(find.text('PRACTISE ONE WORD'), findsNothing);
    });

    testWidgets('your words, sorted by how many tries they take', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final t0 = DateTime(2026, 11, 13, 9);
      var n = 0;
      Future<void> tries(String hanzi, List<bool> results) async {
        for (final ok in results) {
          await store.logSpeakTry(word(hanzi).id, ok, t0.add(Duration(minutes: n++)));
        }
      }

      await tries('买', [false, false, false]);
      await tries('谢谢', [true, true]);
      await tries('不客气', [false, true]);
      await tester.pumpWidget(AppScope(
        library: lib,
        store: store,
        speaker: Speaker(lib),
        device: NoDevice(),
        child: const MaterialApp(home: SayItWordsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Struggling (1)'), findsOneWidget);
      expect(find.text('Getting there (1)'), findsOneWidget);
      expect(find.text('Easy (1)'), findsOneWidget);
      expect(find.text('Practise the 1 struggling'), findsOneWidget);
      expect(find.textContaining('3 tries, not right yet'), findsOneWidget);
      expect(find.textContaining('Usually 1 try · right 2 times'), findsOneWidget);
      expect(find.textContaining('Usually 2 tries · right once'), findsOneWidget);
    });

    testWidgets('a quick tap asks to hold the button', (tester) async {
      await pumpScreen(tester, _FakeChecker('谢谢'), [word('谢谢')]);
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      expect(find.text('Hold the button down while you speak, then let go.'), findsOneWidget);
    });
  });
}

class _FakeRecorder implements Recorder {
  @override
  Future<bool> allowed() async => true;
  @override
  Future<void> start() async {}
  @override
  Future<String?> stop() async => 'fake.wav';
  @override
  Future<void> dispose() async {}
}

class _FakeChecker implements SpeechChecker {
  _FakeChecker(this.text);

  /// What it "hears"; change it between tries.
  String text;

  @override
  Future<SpeechResult> analyse(String wavPath) async {
    final pitch = trackPitch(readWav(wavOf([...glide(250, 250, seconds: 0.3), ...glide(260, 180, seconds: 0.3)])));
    return SpeechResult(Transcript(text, null), pitch);
  }
}
