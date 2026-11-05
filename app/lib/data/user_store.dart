import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../srs/scheduler.dart';

/// Everything the learner changes: stars, custom lists, flashcard progress,
/// reported problems and settings. Stored on the phone only.
class UserStore extends ChangeNotifier {
  UserStore._(this._prefs) {
    _load();
  }

  static Future<UserStore> open() async => UserStore._(await SharedPreferences.getInstance());

  static const _key = 'user_state_v1';
  final SharedPreferences _prefs;

  /// Starred entry ids, in the order they were starred.
  final List<String> starred = [];

  /// Custom list name -> entry ids. Every entry in a list is also starred.
  final Map<String, List<String>> lists = {};

  /// `entryId:direction` -> progress.
  final Map<String, CardState> cards = {};

  /// Entry id -> what looked wrong.
  final Map<String, String> reported = {};

  /// Entry id -> how hard the learner says the word is for them.
  final Map<String, Difficulty> difficulty = {};

  /// What the front of a Chinese-to-English card shows: hanzi, pinyin or audio.
  String cardFront = 'hanzi';
  bool slowAudio = false;
  bool femaleVoice = true;

  /// Colour each character by its tone, like the pinyin.
  bool toneHanzi = true;

  /// Daily reminder when cards are due, at [reminderMinutes] after midnight.
  bool reminderOn = false;
  int reminderMinutes = 20 * 60;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    _apply(jsonDecode(raw) as Map<String, dynamic>);
  }

  void _apply(Map<String, dynamic> j) {
    starred.clear();
    lists.clear();
    cards.clear();
    reported.clear();
    difficulty.clear();
    starred.addAll(List<String>.from(j['starred'] as List? ?? const []));
    (j['lists'] as Map? ?? const {}).forEach((k, v) => lists[k as String] = List<String>.from(v as List));
    (j['cards'] as Map? ?? const {})
        .forEach((k, v) => cards[k as String] = CardState.fromJson(v as Map<String, dynamic>));
    (j['reported'] as Map? ?? const {}).forEach((k, v) => reported[k as String] = v as String);
    (j['difficulty'] as Map? ?? const {}).forEach((k, v) {
      final d = Difficulty.values.asNameMap()[v];
      if (d != null) difficulty[k as String] = d;
    });
    cardFront = j['cardFront'] as String? ?? cardFront;
    slowAudio = j['slowAudio'] as bool? ?? slowAudio;
    femaleVoice = j['femaleVoice'] as bool? ?? femaleVoice;
    toneHanzi = j['toneHanzi'] as bool? ?? toneHanzi;
    reminderOn = j['reminderOn'] as bool? ?? reminderOn;
    reminderMinutes = j['reminderMinutes'] as int? ?? reminderMinutes;
  }

  Map<String, dynamic> _toJson() => {
        'starred': starred,
        'lists': lists,
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'reported': reported,
        'difficulty': difficulty.map((k, v) => MapEntry(k, v.name)),
        'cardFront': cardFront,
        'slowAudio': slowAudio,
        'femaleVoice': femaleVoice,
        'toneHanzi': toneHanzi,
        'reminderOn': reminderOn,
        'reminderMinutes': reminderMinutes,
      };

  static const backupFormat = 'language-library-backup';

  /// Everything above as one file, for a backup.
  String exportBackup(DateTime now) => const JsonEncoder.withIndent(' ').convert({
        'format': backupFormat,
        'version': 1,
        'saved': now.toIso8601String(),
        'data': _toJson(),
      });

  /// Replaces everything with a backup made by [exportBackup].
  /// Throws [FormatException] if the file is not one, and changes nothing then.
  Future<void> importBackup(String text) async {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      throw const FormatException('This file is not a Language Library backup.');
    }
    if (j is! Map<String, dynamic> || j['format'] != backupFormat || j['data'] is! Map<String, dynamic>) {
      throw const FormatException('This file is not a Language Library backup.');
    }
    final data = j['data'] as Map<String, dynamic>;
    // Check it reads cleanly before touching the current data.
    UserStore._check(data);
    _apply(data);
    await _save();
  }

  static void _check(Map<String, dynamic> data) {
    try {
      List<String>.from(data['starred'] as List? ?? const []);
      (data['lists'] as Map? ?? const {}).forEach((k, v) => List<String>.from(v as List));
      (data['cards'] as Map? ?? const {}).forEach((k, v) => CardState.fromJson(v as Map<String, dynamic>));
      (data['reported'] as Map? ?? const {}).forEach((k, v) => v as String);
    } catch (_) {
      throw const FormatException('This backup file is damaged, so nothing was restored.');
    }
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_toJson()));
  }

  bool isStarred(String id) => starred.contains(id);

  Future<void> toggleStar(String id) {
    if (starred.remove(id)) {
      for (final l in lists.values) {
        l.remove(id);
      }
    } else {
      starred.add(id);
    }
    return _save();
  }

  Future<void> createList(String name) {
    lists.putIfAbsent(name.trim(), () => []);
    return _save();
  }

  Future<void> deleteList(String name) {
    lists.remove(name);
    return _save();
  }

  Future<void> setInList(String list, String id, bool inList) {
    final ids = lists.putIfAbsent(list, () => []);
    if (inList) {
      if (!ids.contains(id)) ids.add(id);
      if (!starred.contains(id)) starred.add(id);
    } else {
      ids.remove(id);
    }
    return _save();
  }

  /// Ids in a list, or all starred ids when [list] is null.
  List<String> idsIn(String? list) => list == null ? List.of(starred) : List.of(lists[list] ?? const []);

  static String cardKey(String id, Direction d) => '$id:${d.name}';

  CardState? card(String id, Direction d) => cards[cardKey(id, d)];

  Future<void> saveCard(String id, Direction d, CardState state) {
    cards[cardKey(id, d)] = state;
    return _save();
  }

  Future<void> report(String id, String note) {
    reported[id] = note;
    return _save();
  }

  Future<void> clearReport(String id) {
    reported.remove(id);
    return _save();
  }

  /// Pass null to clear the score.
  Future<void> setDifficulty(String id, Difficulty? d) {
    if (d == null) {
      difficulty.remove(id);
    } else {
      difficulty[id] = d;
    }
    return _save();
  }

  Future<void> setCardFront(String v) {
    cardFront = v;
    return _save();
  }

  Future<void> setSlowAudio(bool v) {
    slowAudio = v;
    return _save();
  }

  Future<void> setToneHanzi(bool v) {
    toneHanzi = v;
    return _save();
  }

  Future<void> setReminder({required bool on, int? minutes}) {
    reminderOn = on;
    reminderMinutes = minutes ?? reminderMinutes;
    return _save();
  }

  Future<void> setFemaleVoice(bool v) {
    femaleVoice = v;
    return _save();
  }
}

/// The learner's own score for a word, separate from flashcard scheduling.
enum Difficulty {
  easy('Easy'),
  ok('OK'),
  hard('Hard');

  const Difficulty(this.label);
  final String label;
}
