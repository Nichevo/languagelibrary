import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/user_store.dart';

/// Opens Dropbox's "Allow access?" page and returns the address Dropbox sends
/// back to the app, which carries the one-time code. Replaced in tests.
typedef Authorize = Future<String> Function(String url, String callbackScheme);

Future<String> _browser(String url, String scheme) => FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: scheme);

/// Keeps progress in step between devices through one file in the person's own
/// Dropbox, in the app's own folder (under Apps), which is all the app can see.
///
/// Each sync downloads the file, joins it into this device's progress
/// ([UserStore.mergeFrom]) and uploads the result. Dropbox's file version (rev)
/// makes sure a second device syncing at the same moment isn't overwritten:
/// if the file changed in between, the sync starts again.
///
/// Signing in uses PKCE, so the app holds no secret: only the app key below,
/// which names the app on Dropbox and isn't a password.
class DropboxSync extends ChangeNotifier {
  DropboxSync(this._prefs, {http.Client? client, Authorize? authorize})
      : _http = client ?? http.Client(),
        _authorize = authorize ?? _browser {
    _load();
  }

  static Future<DropboxSync> open() async => DropboxSync(await SharedPreferences.getInstance());

  /// From the Dropbox App Console (an "App folder" app with files.content.read and .write).
  static const appKey = 'zeb7n8dmb42hbvu';
  static const callbackScheme = 'langlib';
  static const redirectUri = 'langlib://dropbox-auth';
  static const path = '/language-library-sync.json';

  /// Kept apart from the learner's data, so backups never carry the sign-in.
  static const _key = 'dropbox_v1';

  final SharedPreferences _prefs;
  final http.Client _http;
  final Authorize _authorize;

  String? _refreshToken;
  String? _accessToken;
  DateTime _accessExpires = DateTime.fromMillisecondsSinceEpoch(0);

  /// When the last sync finished, and what it brought in.
  DateTime? lastSync;
  String? lastResult;

  /// Why the last sync failed, in words for the Sync page; null when it worked.
  String? lastError;

  bool _busy = false;
  bool get busy => _busy;
  bool get linked => _refreshToken != null;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _refreshToken = j['refresh'] as String?;
      final at = j['lastSync'] as int?;
      lastSync = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
      lastResult = j['lastResult'] as String?;
    } catch (_) {}
  }

  Future<void> _persist() => _prefs.setString(
        _key,
        jsonEncode({
          'refresh': _refreshToken,
          'lastSync': lastSync?.millisecondsSinceEpoch,
          'lastResult': lastResult,
        }),
      );

  /// Asks Dropbox for permission (the person signs in and taps Allow), then
  /// syncs once. Returns false if they cancel.
  Future<bool> link(UserStore store) async {
    final verifier = _randomVerifier();
    final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
    final url = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'redirect_uri': redirectUri,
    }).toString();
    final String back;
    try {
      back = await _authorize(url, callbackScheme);
    } catch (_) {
      return false; // closed the page
    }
    final params = Uri.parse(back).queryParameters;
    final code = params['code'];
    if (code == null) {
      lastError = params['error'] == 'access_denied' ? null : 'Dropbox did not allow the link. Try again.';
      notifyListeners();
      return false;
    }
    final res = await _http.post(Uri.https('api.dropboxapi.com', '/oauth2/token'), body: {
      'code': code,
      'grant_type': 'authorization_code',
      'client_id': appKey,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
    });
    if (res.statusCode != 200) {
      lastError = 'Dropbox did not accept the link (${res.statusCode}). Try again.';
      notifyListeners();
      return false;
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _refreshToken = j['refresh_token'] as String?;
    _accessToken = j['access_token'] as String?;
    _accessExpires = DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 0));
    lastError = null;
    await _persist();
    notifyListeners();
    await sync(store);
    return _refreshToken != null;
  }

  /// Forgets the link on this device and tells Dropbox to drop the permission.
  /// The sync file stays in Dropbox for the other device.
  Future<void> unlink() async {
    final token = _accessToken;
    _refreshToken = null;
    _accessToken = null;
    lastSync = null;
    lastResult = null;
    lastError = null;
    await _persist();
    notifyListeners();
    if (token != null) {
      try {
        await _http.post(Uri.https('api.dropboxapi.com', '/2/auth/token/revoke'),
            headers: {'Authorization': 'Bearer $token'});
      } catch (_) {}
    }
  }

  /// Joins the progress in Dropbox with this device's, and saves the result
  /// back to Dropbox. Does nothing if not linked or a sync is already running.
  /// Returns what came in, or null if it didn't sync.
  Future<MergeResult?> sync(UserStore store) async {
    if (!linked || _busy) return null;
    _busy = true;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final token = await _token();
        final (text, rev) = await _download(token);
        var result = const MergeResult();
        if (text != null) result = await store.mergeFrom(UserStore.backupData(text));
        if (await _upload(token, store.exportBackup(DateTime.now()), rev)) {
          lastSync = DateTime.now();
          lastResult = result.describe();
          lastError = null;
          await _persist();
          return result;
        }
        // The file changed while this sync ran: start again with the new one.
      }
      throw const _SyncError('Your other device kept changing the sync file. Try again in a moment.');
    } on _SyncError catch (e) {
      lastError = e.message;
    } on FormatException {
      lastError = 'The sync file in Dropbox is damaged, so nothing was changed. Delete '
          'language-library-sync.json from the app\'s folder in Dropbox (under Apps), then sync again.';
    } on _SignedOut {
      _refreshToken = null;
      _accessToken = null;
      lastError = 'Dropbox no longer allows access. Link Dropbox again.';
      await _persist();
    } catch (_) {
      lastError = 'Couldn\'t reach Dropbox. It will try again next time you open the app.';
    } finally {
      _busy = false;
      notifyListeners();
    }
    return null;
  }

  /// A current access token, refreshed from the long-lived one when needed.
  Future<String> _token() async {
    final t = _accessToken;
    if (t != null && DateTime.now().isBefore(_accessExpires.subtract(const Duration(minutes: 5)))) return t;
    final res = await _http.post(Uri.https('api.dropboxapi.com', '/oauth2/token'), body: {
      'grant_type': 'refresh_token',
      'refresh_token': _refreshToken!,
      'client_id': appKey,
    });
    if (res.statusCode == 400 || res.statusCode == 401) throw const _SignedOut();
    if (res.statusCode != 200) throw _SyncError('Dropbox sign-in failed (${res.statusCode}).');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = j['access_token'] as String;
    _accessExpires = DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 0));
    return _accessToken!;
  }

  /// The sync file and its version, or (null, null) if there isn't one yet.
  Future<(String?, String?)> _download(String token) async {
    final res = await _http.post(Uri.https('content.dropboxapi.com', '/2/files/download'), headers: {
      'Authorization': 'Bearer $token',
      'Dropbox-API-Arg': jsonEncode({'path': path}),
    });
    if (res.statusCode == 409 && res.body.contains('not_found')) return (null, null);
    if (res.statusCode == 401) throw const _SignedOut();
    if (res.statusCode != 200) throw _SyncError('Dropbox download failed (${res.statusCode}).');
    String? rev;
    try {
      rev = (jsonDecode(res.headers['dropbox-api-result'] ?? '{}') as Map)['rev'] as String?;
    } catch (_) {}
    return (utf8.decode(res.bodyBytes, allowMalformed: true), rev);
  }

  /// Saves [text] as the sync file, only if it is still at version [rev]
  /// (or still missing when [rev] is null). False if another device got there first.
  Future<bool> _upload(String token, String text, String? rev) async {
    final mode = rev == null ? 'add' : {'.tag': 'update', 'update': rev};
    final res = await _http.post(
      Uri.https('content.dropboxapi.com', '/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({'path': path, 'mode': mode, 'autorename': false, 'mute': true}),
      },
      body: utf8.encode(text),
    );
    if (res.statusCode == 200) return true;
    if (res.statusCode == 409 && res.body.contains('conflict')) return false;
    if (res.statusCode == 401) throw const _SignedOut();
    throw _SyncError('Dropbox upload failed (${res.statusCode}).');
  }

  static String _randomVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(64, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

class _SyncError implements Exception {
  const _SyncError(this.message);
  final String message;
}

class _SignedOut implements Exception {
  const _SignedOut();
}
