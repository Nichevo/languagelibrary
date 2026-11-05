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

  /// Most cards in one practice session, picked at random; 0 means all of them.
  int sessionSize = 20;

  /// How the Practice tab practises: 'cards', 'listen' or 'type'.
  String practiceMode = 'cards';

  /// Mix a few related words the learner has not starred into each session.
  bool mixRelated = false;

  /// Every flashcard answer, oldest first, for the statistics screen.
  final List<Review> reviews = [];

  /// Day ('2026-11-05') -> how the starred cards stood at the end of that day.
  final Map<String, Snapshot> snapshots = {};

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
    reviews.clear();
    snapshots.clear();
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
    sessionSize = j['sessionSize'] as int? ?? sessionSize;
    mixRelated = j['mixRelated'] as bool? ?? mixRelated;
    practiceMode = j['practiceMode'] as String? ?? practiceMode;
    for (final r in j['reviews'] as List? ?? const []) {
      reviews.add(Review.fromJson(r as List));
    }
    (j['snapshots'] as Map? ?? const {}).forEach((k, v) => snapshots[k as String] = Snapshot.fromJson(v as List));
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
        'sessionSize': sessionSize,
        'mixRelated': mixRelated,
        'practiceMode': practiceMode,
        'reviews': [for (final r in reviews) r.toJson()],
        'snapshots': snapshots.map((k, v) => MapEntry(k, v.toJson())),
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
      for (final r in data['reviews'] as List? ?? const []) {
        Review.fromJson(r as List);
      }
      (data['snapshots'] as Map? ?? const {}).forEach((k, v) => Snapshot.fromJson(v as List));
    } catch (_) {
      throw const FormatException('This backup file is damaged, so nothing was restored.');
    }
  }

  Future<void> _save() async {
    _snapshot(DateTime.now());
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_toJson()));
  }

  /// About how much space the learner's own data takes on the phone.
  int get sizeBytes => utf8.encode(jsonEncode(_toJson())).length;

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

  /// Saves a flashcard answer and logs it, with [spent] time on the card.
  Future<void> recordReview(String id, Direction d, CardState state, Rating rating, Duration spent, DateTime now) {
    final isNew = card(id, d) == null;
    cards[cardKey(id, d)] = state;
    reviews.add(Review(now, spent > maxSpent ? maxSpent : spent, rating, isNew));
    if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    return _save();
  }

  /// Logs a listening or typing answer, which doesn't change when cards come back.
  Future<void> logAnswer(Rating rating, Duration spent, DateTime now) {
    reviews.add(Review(now, spent > maxSpent ? maxSpent : spent, rating, false));
    if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    return _save();
  }

  /// Time on one card counts up to this, so a phone left on the table doesn't add hours.
  static const maxSpent = Duration(minutes: 1);
  static const maxReviews = 50000;

  /// Records today's card counts, so the statistics can show change over time.
  void _snapshot(DateTime now) {
    final counts = List.filled(CardStatus.values.length, 0);
    for (final id in starred) {
      for (final d in Direction.values) {
        counts[CardStatus.of(card(id, d)).index]++;
      }
    }
    final k = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    snapshots[k] = Snapshot(starred.length, counts);
  }

  Future<void> setSessionSize(int v) {
    sessionSize = v;
    return _save();
  }

  Future<void> setPracticeMode(String v) {
    practiceMode = v;
    return _save();
  }

  Future<void> setMixRelated(bool v) {
    mixRelated = v;
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

/// One flashcard answer.
class Review {
  const Review(this.at, this.spent, this.rating, this.isNew);
  final DateTime at;
  final Duration spent;
  final Rating rating;

  /// The first time this card was ever answered.
  final bool isNew;

  List<Object> toJson() => [at.millisecondsSinceEpoch ~/ 1000, spent.inMilliseconds, rating.index, isNew ? 1 : 0];

  factory Review.fromJson(List j) => Review(
        DateTime.fromMillisecondsSinceEpoch((j[0] as int) * 1000),
        Duration(milliseconds: j[1] as int),
        Rating.values[j[2] as int],
        j.length > 3 && j[3] == 1,
      );
}

/// How well a flashcard is known, from how long until it comes back.
enum CardStatus {
  fresh('New', 'Not practised yet'),
  learning('Learning', 'Back within a week'),
  familiar('Familiar', 'Back in 1 to 3 weeks'),
  strong('Strong', 'Back in 3 weeks or more');

  const CardStatus(this.label, this.meaning);
  final String label;
  final String meaning;

  static CardStatus of(CardState? c) {
    if (c == null) return fresh;
    if (c.intervalDays < 7) return learning;
    if (c.intervalDays < 21) return familiar;
    return strong;
  }
}

/// Starred words and cards by [CardStatus] at the end of one day.
class Snapshot {
  const Snapshot(this.starred, this.byStatus);
  final int starred;
  final List<int> byStatus;

  List<int> toJson() => [starred, ...byStatus];

  factory Snapshot.fromJson(List j) {
    final counts = [for (var i = 1; i < j.length; i++) j[i] as int];
    while (counts.length < CardStatus.values.length) {
      counts.add(0);
    }
    return Snapshot(j[0] as int, counts.sublist(0, CardStatus.values.length));
  }
}
