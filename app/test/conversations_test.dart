import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/audio/speaker.dart';
import 'package:language_library/data/conversations.dart';
import 'package:language_library/data/library.dart';
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

  group('a conversation', () {
    late Library lib;
    setUp(() => lib = loadLibraryWithConversations());

    Future<void> open(WidgetTester tester, {bool youStart = false, bool chooseOnly = false, String heard = ''}) async {
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
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
      expect(find.byIcon(Icons.mic), findsNothing);
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
