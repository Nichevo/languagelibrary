import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:language_library/sync/dropbox_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The data another device would put in its sync file.
Map<String, dynamic> dataOf(UserStore s) => UserStore.backupData(s.exportBackup(DateTime(2026, 11, 11)));

void main() {
  const sched = Scheduler();
  final d = Direction.values.first;
  late UserStore phone;
  late UserStore ipad;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    phone = await UserStore.open();
    ipad = await UserStore.open();
  });

  test('joining keeps every answer from both devices, once each', () async {
    final t = DateTime(2026, 11, 10, 9);
    await phone.logAnswer(Rating.good, const Duration(seconds: 3), t, method: 'meaning', id: 'a');
    await ipad.logAnswer(Rating.again, const Duration(seconds: 4), t.add(const Duration(minutes: 1)),
        method: 'pinyin', id: 'b');

    final r = await ipad.mergeFrom(dataOf(phone));
    expect(r.answersAdded, 1);
    expect(ipad.reviews.map((x) => x.id), ['a', 'b'], reason: 'in time order');

    // Syncing again adds nothing.
    final again = await ipad.mergeFrom(dataOf(phone));
    expect(again.answersAdded, 0);
    expect(again.describe(), 'Already up to date');

    // And the phone gets the iPad's answer back.
    await phone.mergeFrom(dataOf(ipad));
    expect(phone.reviews.map((x) => x.id), ['a', 'b']);
  });

  test('stars join, and un-starring on one device carries over', () async {
    await phone.toggleStar('a');
    await ipad.toggleStar('b');
    await ipad.mergeFrom(dataOf(phone));
    await phone.mergeFrom(dataOf(ipad));
    expect(phone.starred.toSet(), {'a', 'b'});
    expect(ipad.starred.toSet(), {'a', 'b'});

    // Un-star "a" on the iPad later; the phone follows.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await ipad.toggleStar('a');
    final r = await phone.mergeFrom(dataOf(ipad));
    expect(phone.starred, ['b']);
    expect(r.starsRemoved, 1);
  });

  test('the flashcard answered last wins', () async {
    final early = DateTime(2026, 11, 1, 9);
    final late = DateTime(2026, 11, 3, 9);
    final c1 = sched.review(null, Rating.good, early);
    await phone.recordReview('a', d, c1, Rating.good, Duration.zero, early);
    final c2 = sched.review(c1, Rating.again, late);
    await ipad.recordReview('a', d, c1, Rating.good, Duration.zero, early);
    await ipad.recordReview('a', d, c2, Rating.again, Duration.zero, late);

    await phone.mergeFrom(dataOf(ipad));
    expect(phone.card('a', d)!.reps, c2.reps, reason: "the iPad's later answer");

    // The older one coming back doesn't undo it.
    final older = await UserStore.open();
    await older.recordReview('a', d, c1, Rating.good, Duration.zero, early);
    await phone.mergeFrom(dataOf(older));
    expect(phone.card('a', d)!.reps, c2.reps);
  });

  test('lists, scores and reports follow the latest change; settings stay', () async {
    await phone.createList('This week');
    await phone.setInList('This week', 'a', true);
    await phone.setDifficulty('a', Difficulty.hard);
    await phone.report('a', 'tone looks wrong');
    await phone.setSessionSize(5);
    await ipad.setSessionSize(30);

    await ipad.mergeFrom(dataOf(phone));
    expect(ipad.lists['This week'], ['a']);
    expect(ipad.starred, ['a']);
    expect(ipad.difficulty['a'], Difficulty.hard);
    expect(ipad.reported['a'], 'tone looks wrong');
    expect(ipad.sessionSize, 30, reason: 'settings are per device');

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await ipad.deleteList('This week');
    await ipad.setDifficulty('a', null);
    await phone.mergeFrom(dataOf(ipad));
    expect(phone.lists.containsKey('This week'), isFalse);
    expect(phone.difficulty.containsKey('a'), isFalse);
  });

  test('progress saved before sync existed is joined, not lost', () async {
    // Old data has no change times at all.
    final old = {
      'starred': ['x'],
      'cards': {
        'x:${d.name}': {'reps': 2, 'interval': 3.0, 'ease': 2.5, 'due': '2026-11-20T09:00:00.000', 'lapses': 0},
      },
      'reviews': [
        [1762765200, 2000, 2, 1],
      ],
    };
    await phone.toggleStar('y');
    final r = await phone.mergeFrom(old);
    expect(phone.starred.toSet(), {'x', 'y'});
    expect(phone.card('x', d)!.reps, 2);
    expect(r.answersAdded, 1);
    expect(r.describe(), 'Added 1 answer, 1 starred word and 1 flashcard from your other device');
  });

  test('a damaged file changes nothing', () async {
    await phone.toggleStar('a');
    expect(() => phone.mergeFrom({'reviews': 'nope'}), throwsFormatException);
    expect(() => UserStore.backupData('{"hello": 1}'), throwsFormatException);
    expect(phone.starred, ['a']);
  });

  group('Dropbox', () {
    late SharedPreferences prefs;
    String? fileInDropbox;
    var rev = 0;
    late List<String> calls;
    void Function()? afterDownload;

    MockClient dropbox() => MockClient((req) async {
          calls.add(req.url.path);
          switch (req.url.path) {
            case '/oauth2/token':
              final grant = req.bodyFields['grant_type'];
              expect(req.bodyFields['client_id'], DropboxSync.appKey);
              if (grant == 'authorization_code') {
                expect(req.bodyFields['code'], 'CODE');
                expect(req.bodyFields['code_verifier'], hasLength(64));
              }
              return http.Response(
                  jsonEncode({'access_token': 'AT', 'refresh_token': 'RT', 'expires_in': 14400}), 200);
            case '/2/files/download':
              if (fileInDropbox == null) return http.Response('{"error_summary": "path/not_found/"}', 409);
              final res = http.Response.bytes(utf8.encode(fileInDropbox!), 200,
                  headers: {'dropbox-api-result': jsonEncode({'rev': 'r$rev'})});
              afterDownload?.call();
              afterDownload = null;
              return res;
            case '/2/files/upload':
              final arg = jsonDecode(req.headers['Dropbox-API-Arg']!) as Map;
              expect(arg['path'], DropboxSync.path);
              final mode = arg['mode'];
              if (mode is Map && mode['update'] != 'r$rev') {
                return http.Response('{"error_summary": "path/conflict/file/"}', 409);
              }
              fileInDropbox = utf8.decode(req.bodyBytes);
              rev++;
              return http.Response('{}', 200);
            case '/2/auth/token/revoke':
              return http.Response('null', 200);
          }
          return http.Response('not found', 404);
        });

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      fileInDropbox = null;
      rev = 0;
      calls = [];
      afterDownload = null;
    });

    test('link, sync both ways, unlink', () async {
      String? askedFor;
      final onPhone = DropboxSync(prefs, client: dropbox(), authorize: (url, scheme) async {
        askedFor = url;
        expect(scheme, 'langlib');
        return '${DropboxSync.redirectUri}?code=CODE';
      });
      await phone.toggleStar('a');
      expect(await onPhone.link(phone), isTrue);
      expect(askedFor, contains('code_challenge_method=S256'));
      expect(askedFor, contains('token_access_type=offline'));
      expect(onPhone.linked, isTrue);
      expect(fileInDropbox, contains('"a"'), reason: 'first sync uploads the phone');
      expect(onPhone.lastError, isNull);

      // The iPad links and gets the phone's star; its own answer goes up.
      final onIpad = DropboxSync(prefs, client: dropbox(), authorize: (_, _) async => '${DropboxSync.redirectUri}?code=CODE');
      await ipad.logAnswer(Rating.good, Duration.zero, DateTime(2026, 11, 11), method: 'meaning', id: 'b');
      await onIpad.link(ipad);
      expect(ipad.starred, ['a']);
      expect(onIpad.lastResult, 'Added 1 starred word from your other device');

      final r = await onPhone.sync(phone);
      expect(r!.answersAdded, 1);
      expect(phone.reviews.single.id, 'b');

      await onPhone.unlink();
      expect(onPhone.linked, isFalse);
      expect(calls.last, '/2/auth/token/revoke');
      expect(await onPhone.sync(phone), isNull);
    });


    test('a cancelled link changes nothing', () async {
      final s = DropboxSync(prefs, client: dropbox(), authorize: (_, _) async => throw Exception('closed'));
      expect(await s.link(phone), isFalse);
      expect(s.linked, isFalse);
      expect(calls, isEmpty);
    });

    test('an upload conflict starts the sync again with the newer file', () async {
      final s = DropboxSync(prefs, client: dropbox(), authorize: (_, _) async => '${DropboxSync.redirectUri}?code=CODE');
      await s.link(phone);
      // The iPad saves between the phone's download and upload.
      await ipad.toggleStar('z');
      afterDownload = () {
        fileInDropbox = ipad.exportBackup(DateTime(2026, 11, 11));
        rev++;
      };
      final r = await s.sync(phone);
      expect(s.lastError, isNull);
      expect(r, isNotNull);
      expect(phone.starred, contains('z'), reason: "the iPad's change was joined, not lost");
      expect(fileInDropbox, contains('"z"'));
    });
  });
}
