import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/audio/speaker.dart';
import 'package:language_library/data/conversations.dart';
import 'package:language_library/data/library.dart';
import 'package:language_library/data/talk.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/device/device.dart';
import 'package:language_library/speech/pitch.dart';
import 'package:language_library/speech/recognizer.dart';
import 'package:language_library/speech/speech_service.dart';
import 'package:language_library/ui/common.dart';
import 'package:language_library/ui/conversation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'say_it_test.dart' show glide, wavOf;
import 'package:language_library/speech/wav.dart';

Conversations loadConversations() => Conversations.fromJson(
    jsonDecode(File('assets/data/conversations.json').readAsStringSync()) as Map<String, dynamic>);

Library loadLibraryWithConversations() {
  final data = jsonDecode(File('assets/data/library.json').readAsStringSync()) as Map<String, dynamic>;
  return Library.fromJson(data, conversations: loadConversations());
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
  String text;

  @override
  Future<SpeechResult> analyse(String wavPath) async {
    final pitch = trackPitch(readWav(wavOf(glide(250, 200, seconds: 0.4))));
    return SpeechResult(Transcript(text, null), pitch);
  }
}

void main() {
  final conv = loadConversations();

  group('the checked scenes', () {
    test('every scene, line and reply can be found', () {
      expect(conv.scenes, isNotEmpty);
      for (final s in conv.scenes) {
        expect(s.hsk, lessThanOrEqualTo(2), reason: s.id);
        for (final l in s.lines) {
          expect(conv.line(l), isNotNull, reason: l);
          expect(conv.next.containsKey(l), isTrue, reason: l);
        }
        // Every line after the first is a turn with three choices, at least one right.
        for (final l in s.lines.skip(1)) {
          final c = conv.choices(l);
          expect(c, isNotNull, reason: l);
          expect(c!.length, 3, reason: l);
          expect(c.where((x) => x.right), isNotEmpty, reason: l);
          for (final x in c.where((x) => x.right)) {
            if (x.then != null) expect(conv.next.containsKey(x.then), isTrue, reason: '$l -> ${x.then}');
          }
        }
      }
    });

    test('the order of the choices is mixed but fixed', () {
      final a = conv.choices('d2.2')!.map((c) => c.entry.id).toList();
      final b = conv.choices('d2.2')!.map((c) => c.entry.id).toList();
      expect(a, b);
      final firsts = {
        for (final s in conv.scenes)
          for (final l in s.lines.skip(1)) conv.choices(l)!.indexWhere((c) => c.right)
      };
      expect(firsts.length, greaterThan(1), reason: 'the right reply should not always be in the same place');
    });

    test('lines are full entries that Say it can check', () {
      final e = conv.line('d2.1')!;
      expect(e.simplified, '你好吗？');
      expect(e.syllables.map((s) => s.hanzi).join(), '你好吗');
      expect(e.meanings.single, 'How are you?');
      expect(e.sources.single, contains('COERLL'));
    });
  });

  group('a go at a scene', () {
    TalkRun run({int wrong = 0, bool said = true}) => TalkRun(
          at: DateTime(2026, 11, 17, 9),
          scene: 'd2',
          seconds: 75,
          finished: true,
          englishPeeks: 2,
          turns: [
            const TalkTurn(line: 'd2.1', picked: 'conv-d2.1', tries: 1, saidWell: true, heardRight: 3, heardOf: 3, choice: false),
            TalkTurn(line: 'd2.2', picked: 'conv-d2.2', wrongPicks: wrong, tries: 2, saidWell: said,
                heardRight: said ? 3 : 2, heardOf: 3, slips: said ? const [] : const ['好>号']),
          ],
        );

    test('reads back what it wrote', () {
      final r = run(wrong: 1, said: false);
      final back = TalkRun.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map);
      expect(back.key, r.key);
      expect(back.turns.last.slips, ['好>号']);
      expect(back.turns.first.choice, isFalse);
      expect(back.englishPeeks, 2);
      expect(back.choices, hasLength(1));
      expect(back.triesPerReply, 1.5);
    });

    test('marks: green when right and said well, red when missed', () {
      expect(run().mark, TalkMark.good);
      expect(run(wrong: 1).mark, TalkMark.poor);
      expect(run(said: false).mark, TalkMark.middling);
      expect(reviewDue(run(wrong: 1)), DateTime(2026, 11, 19, 9));
    });

    test('goes from both devices are kept once each when syncing', () async {
      SharedPreferences.setMockInitialValues({});
      final phone = await UserStore.open();
      final ipad = await UserStore.open();
      await phone.logTalkRun(run());
      await ipad.logTalkRun(TalkRun.fromJson(run(wrong: 1).toJson()..['at'] = DateTime(2026, 11, 18).millisecondsSinceEpoch));
      Map<String, dynamic> dataOf(UserStore s) => UserStore.backupData(s.exportBackup(DateTime(2026, 11, 18)));
      await ipad.mergeFrom(dataOf(phone));
      await ipad.mergeFrom(dataOf(phone));
      expect(ipad.talkRuns.map((r) => r.at.day), [17, 18]);
    });
  });

  group('a conversation', () {
    late Library lib;
    setUp(() => lib = loadLibraryWithConversations());

    late UserStore store;

    Future<void> open(WidgetTester tester, {bool youStart = false, bool chooseOnly = false, String heard = ''}) async {
      SharedPreferences.setMockInitialValues({});
      store = await UserStore.open();
      final scene = lib.conversations.scenes.firstWhere((s) => s.id == 'd2');
      await tester.pumpWidget(AppScope(
        library: lib,
        store: store,
        speaker: Speaker(lib),
        device: NoDevice(),
        child: MaterialApp(
          home: ConversationScreen(
            scene: scene,
            youStart: youStart,
            chooseOnly: chooseOnly,
            recorder: _FakeRecorder(),
            checker: _FakeChecker(heard),
            autoPlay: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Finder choice(String zh) => find.descendant(of: find.byType(ListTile), matching: find.text(zh));

    testWidgets('the app speaks first, a wrong pick is explained, a right one is said', (tester) async {
      await open(tester, heard: '我很好');
      expect(find.text('你好吗？'), findsOneWidget);
      expect(find.text('PICK A REPLY'), findsOneWidget);

      final wrong = conv.choices('d2.2')!.firstWhere((c) => !c.right).entry;
      await tester.tap(choice(wrong.simplified));
      await tester.pumpAndSettle();
      expect(find.textContaining('Good Chinese, but it doesn\'t answer'), findsOneWidget);

      await tester.tap(choice('我很好。'));
      await tester.pumpAndSettle();
      expect(find.text('Good choice'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));
      await gesture.up();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('WHAT THE RECOGNISER HEARD'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Carry on'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Carry on'));
      await tester.pumpAndSettle();
      expect(find.text('said well first try'), findsOneWidget);
      expect(find.text('你忙吗？'), findsWidgets);
      // The reply counts toward the daily goal; the words in it count as Say it tries.
      expect(store.reviews.where((r) => r.method == 'talk'), hasLength(1));
      expect(store.speakTries, isNotEmpty);
    });

    testWidgets('stopping part way asks, then shows the review and saves the go', (tester) async {
      await open(tester, chooseOnly: true);
      await tester.tap(choice('我很好。'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.text('Stop this scene?'), findsOneWidget);
      await tester.tap(find.text('Stop and review'));
      await tester.pumpAndSettle();
      expect(find.text('Stopped early'), findsOneWidget);
      expect(find.text('How it went'), findsOneWidget);
      expect(store.talkRuns, hasLength(1));
      expect(store.talkRuns.single.finished, isFalse);
      expect(store.talkRuns.single.turns.single.picked, 'conv-d2.2');
    });

    testWidgets('choose only: no mic, and the scene runs to the end', (tester) async {
      await open(tester, chooseOnly: true);
      expect(find.byIcon(Icons.mic), findsNothing);
      // Answer every turn with a right reply until the end.
      for (var i = 0; i < 6 && find.text('PICK A REPLY').evaluate().isNotEmpty; i++) {
        final tiles = find.byType(ListTile).evaluate().toList();
        var tapped = false;
        for (final c in conv.scenes.firstWhere((s) => s.id == 'd2').lines.skip(1)) {
          for (final r in conv.choices(c)!.where((x) => x.right)) {
            final f = choice(r.entry.simplified);
            if (!tapped && f.evaluate().isNotEmpty) {
              await tester.tap(f.first);
              await tester.pumpAndSettle();
              tapped = true;
            }
          }
        }
        expect(tapped || tiles.isEmpty, isTrue);
      }
      expect(find.text('End of the conversation'), findsOneWidget);
      expect(find.text('How it went'), findsOneWidget);
      expect(find.text('TURN BY TURN'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(store.talkRuns.single.finished, isTrue);
      expect(store.talkRuns.single.mark, TalkMark.good);
    });

    testWidgets('the scene list marks scenes you have done and shows new ones', (tester) async {
      SharedPreferences.setMockInitialValues({});
      store = await UserStore.open();
      await store.logTalkRun(TalkRun(
        at: DateTime.now(),
        scene: 'd2',
        seconds: 40,
        finished: true,
        chooseOnly: true,
        turns: const [
          TalkTurn(line: 'd2.2', picked: 'conv-d2.2', wrongPicks: 1),
          TalkTurn(line: 'd2.4', picked: 'conv-d2.4', wrongPicks: 2),
        ],
      ));
      await tester.pumpWidget(AppScope(
        library: lib,
        store: store,
        speaker: Speaker(lib),
        device: NoDevice(),
        child: const MaterialApp(home: ConversationsScreen(autoPlay: false)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Last: 0/2 right'), findsOneWidget);
      expect(find.byTooltip('Needs another go'), findsOneWidget);
      expect(find.byTooltip('New'), findsWidgets);
    });

    testWidgets('you start: your first line comes with nothing to choose', (tester) async {
      await open(tester, youStart: true, chooseOnly: true);
      expect(find.text('Your line'), findsOneWidget);
      expect(find.text('你好吗？'), findsOneWidget);
      await tester.tap(find.text('Carry on'));
      await tester.pumpAndSettle();
      // The app answers as the second speaker, then it's your turn again.
      expect(find.text('我很好。'), findsOneWidget);
      expect(find.text('PICK A REPLY'), findsOneWidget);
    });
  });
}
