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

  /// What the front of a Chinese-to-English card shows: hanzi, pinyin or audio.
  String cardFront = 'hanzi';
  bool slowAudio = false;
  bool femaleVoice = true;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    starred.addAll(List<String>.from(j['starred'] as List? ?? const []));
    (j['lists'] as Map? ?? const {}).forEach((k, v) => lists[k as String] = List<String>.from(v as List));
    (j['cards'] as Map? ?? const {})
        .forEach((k, v) => cards[k as String] = CardState.fromJson(v as Map<String, dynamic>));
    (j['reported'] as Map? ?? const {}).forEach((k, v) => reported[k as String] = v as String);
    cardFront = j['cardFront'] as String? ?? cardFront;
    slowAudio = j['slowAudio'] as bool? ?? slowAudio;
    femaleVoice = j['femaleVoice'] as bool? ?? femaleVoice;
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(
      _key,
      jsonEncode({
        'starred': starred,
        'lists': lists,
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'reported': reported,
        'cardFront': cardFront,
        'slowAudio': slowAudio,
        'femaleVoice': femaleVoice,
      }),
    );
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

  Future<void> setCardFront(String v) {
    cardFront = v;
    return _save();
  }

  Future<void> setSlowAudio(bool v) {
    slowAudio = v;
    return _save();
  }

  Future<void> setFemaleVoice(bool v) {
    femaleVoice = v;
    return _save();
  }
}
