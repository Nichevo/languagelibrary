import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';
import '../models/journey_week.dart';
import '../srs/scheduler.dart';
import 'key_sounds.dart';
import 'talk.dart';

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

  /// What the front of a Chinese-to-English card shows: hanzi, pinyin, audio,
  /// or a mix ('mix' = hanzi or pinyin, 'mixAll' = any of the three).
  String cardFront = 'hanzi';
  bool slowAudio = false;

  /// "Put in order" questions: drag the words into order instead of tapping them.
  bool orderByDrag = false;
  bool femaleVoice = true;

  /// Colour each character by its tone, like the pinyin.
  bool toneHanzi = true;

  /// Daily reminder when cards are due, at [reminderMinutes] after midnight.
  bool reminderOn = false;
  int reminderMinutes = 20 * 60;

  /// Most cards in one practice session, picked at random; 0 means all of them.
  int sessionSize = 20;

  /// Answers a day the Today card aims for.
  int dailyGoal = 20;

  /// How the Practice tab practises: 'cards', 'listen' (multiple choice) or 'type'.
  String practiceMode = 'cards';

  /// Which multiple-choice question: see `Choice` in drill_screen.dart ('mix' varies).
  String choiceKind = 'listen';

  /// The time (milliseconds since 1970) of the last home-screen quiz answer brought
  /// into [reviews], so each one is brought in once.
  int widgetAnswersUpTo = 0;

  /// How the Progress charts group time: 'day', 'week' or 'month'.
  String statsPeriod = 'week';

  /// Mix a few related words the learner has not starred into each session.
  bool mixRelated = false;

  /// HSK levels shown in the library, word of the day and practice extras.
  /// Levels added to the app later start hidden until switched on here.
  final Set<int> levels = {1, 2, 3};

  /// Show the phrasebook sentences in the library.
  bool showSentences = true;

  /// The learning journey: a week-by-week plan that grows from the learner's
  /// own words. [journeyAsked] is set once the learner has said yes or not now.
  bool journeyOn = false;
  bool journeyAsked = false;

  /// How weeks are chosen, any mix of 'connections', 'topics', 'characters',
  /// 'sentences' and 'hsk'. Weeks take turns between the ones switched on.
  final Set<String> journeyPaths = {'connections', 'topics'};

  /// New words a week.
  int journeyPace = 20;

  /// Every this many weeks is a review week with no new words; 0 for never.
  int reviewEvery = 4;

  /// Change the app's colour at each milestone (words known).
  bool milestoneColours = true;

  /// The journey's weeks, oldest first. Synced between devices as a whole.
  final List<JourneyWeek> weeks = [];
  static const maxWeeks = 104;

  /// The week the learner picked for next week, used when it starts.
  JourneyWeek? nextWeek;

  /// The start ('2026-11-09') of a finished week whose recap hasn't been seen.
  String? recapPending;

  /// The highest milestone already celebrated.
  int milestoneSeen = 0;

  /// Where a Say it list that carries on (the week's Sentences day) was left
  /// today: '2026-11-14|list key' -> the id of the next entry to show. Only
  /// today's places are kept.
  final Map<String, String> sayItPlaces = {};

  /// Week days mix practice types (meet, hear, see, say) instead of mostly
  /// flashcards. See data/week_steps.dart.
  bool weekMix = true;

  /// The words done today in each step of a mixed week day, keyed like
  /// '2026-11-18|2026-11-16|2|0' (today, week start, day, step). Only today's
  /// are kept.
  final Map<String, List<String>> weekSteps = {};

  /// Whether [e] belongs to the content switched on in Settings. The curated
  /// everyday phrases and starred words always show.
  bool shows(Entry e) {
    if (e.isSentence) return showSentences || _starredSet.contains(e.id);
    return e.hsk == null || e.curated || levels.contains(e.hsk) || _starredSet.contains(e.id);
  }

  // Rebuilt after every change, since [starred] is a list.
  Set<String>? _starredCache;
  Set<String> get _starredSet => _starredCache ??= starred.toSet();

  /// Every flashcard answer, oldest first, for the statistics screen.
  final List<Review> reviews = [];

  /// Every Say it try, oldest first: how many tries each word takes.
  final List<SpeakTry> speakTries = [];
  static const maxSpeakTries = 20000;

  /// Every Key sounds answer, oldest first: which sounds are trouble.
  final List<SoundTry> soundTries = [];
  static const maxSoundTries = 20000;

  /// Every conversation, finished or stopped early, oldest first.
  final List<TalkRun> talkRuns = [];
  static const maxTalkRuns = 3000;

  /// Day ('2026-11-05') -> how the starred cards stood at the end of that day.
  final Map<String, Snapshot> snapshots = {};

  /// When each card first became familiar (back in a week or more), by card
  /// key. Cards that were already familiar before this was recorded have
  /// [unknownDate].
  final Map<String, DateTime> firstKnown = {};
  static final unknownDate = DateTime.fromMillisecondsSinceEpoch(0);

  /// When each starred word, list, card, score and report last changed on this
  /// device or one it synced with (milliseconds since 1970), keyed like
  /// 'star:ID', 'list:NAME', 'card:ID:direction', 'diff:ID', 'report:ID'. A sync
  /// keeps whichever side changed something last, so un-starring carries over.
  final Map<String, int> stamps = {};

  void _stamp(String key, [DateTime? at]) => stamps[key] = (at ?? DateTime.now()).millisecondsSinceEpoch;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    _apply(jsonDecode(raw) as Map<String, dynamic>);
  }

  void _apply(Map<String, dynamic> j) {
    _starredCache = null;
    starred.clear();
    lists.clear();
    cards.clear();
    reported.clear();
    difficulty.clear();
    reviews.clear();
    speakTries.clear();
    soundTries.clear();
    talkRuns.clear();
    snapshots.clear();
    firstKnown.clear();
    stamps.clear();
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
    orderByDrag = j['orderByDrag'] as bool? ?? orderByDrag;
    femaleVoice = j['femaleVoice'] as bool? ?? femaleVoice;
    toneHanzi = j['toneHanzi'] as bool? ?? toneHanzi;
    reminderOn = j['reminderOn'] as bool? ?? reminderOn;
    reminderMinutes = j['reminderMinutes'] as int? ?? reminderMinutes;
    sessionSize = j['sessionSize'] as int? ?? sessionSize;
    dailyGoal = j['dailyGoal'] as int? ?? dailyGoal;
    mixRelated = j['mixRelated'] as bool? ?? mixRelated;
    practiceMode = j['practiceMode'] as String? ?? practiceMode;
    if (j['levels'] case final List l) {
      levels
        ..clear()
        ..addAll(l.cast<int>());
    }
    showSentences = j['showSentences'] as bool? ?? showSentences;
    journeyOn = j['journeyOn'] as bool? ?? false;
    journeyAsked = j['journeyAsked'] as bool? ?? false;
    if (j['journeyPaths'] case final List l) {
      journeyPaths
        ..clear()
        ..addAll(l.cast<String>());
    }
    journeyPace = j['journeyPace'] as int? ?? journeyPace;
    reviewEvery = j['reviewEvery'] as int? ?? reviewEvery;
    milestoneColours = j['milestoneColours'] as bool? ?? milestoneColours;
    weeks.clear();
    for (final w in j['weeks'] as List? ?? const []) {
      weeks.add(JourneyWeek.fromJson(w as Map<String, dynamic>));
    }
    nextWeek = j['nextWeek'] == null ? null : JourneyWeek.fromJson(j['nextWeek'] as Map<String, dynamic>);
    recapPending = j['recapPending'] as String?;
    milestoneSeen = j['milestoneSeen'] as int? ?? 0;
    sayItPlaces
      ..clear()
      ..addAll(Map<String, String>.from(j['sayItPlaces'] as Map? ?? const {}));
    weekMix = j['weekMix'] as bool? ?? true;
    weekSteps.clear();
    (j['weekSteps'] as Map? ?? const {}).forEach((k, v) => weekSteps[k as String] = List<String>.from(v as List));
    choiceKind = j['choiceKind'] as String? ?? choiceKind;
    widgetAnswersUpTo = j['widgetAnswersUpTo'] as int? ?? 0;
    statsPeriod = j['statsPeriod'] as String? ?? statsPeriod;
    for (final r in j['reviews'] as List? ?? const []) {
      reviews.add(Review.fromJson(r as List));
    }
    for (final t in j['speakTries'] as List? ?? const []) {
      speakTries.add(SpeakTry.fromJson(t as List));
    }
    for (final t in j['soundTries'] as List? ?? const []) {
      soundTries.add(SoundTry.fromJson(t as List));
    }
    for (final t in j['talkRuns'] as List? ?? const []) {
      talkRuns.add(TalkRun.fromJson(t as Map));
    }
    (j['snapshots'] as Map? ?? const {}).forEach((k, v) => snapshots[k as String] = Snapshot.fromJson(v as List));
    (j['firstKnown'] as Map? ?? const {}).forEach(
        (k, v) => firstKnown[k as String] = DateTime.fromMillisecondsSinceEpoch((v as int) * 1000));
    (j['stamps'] as Map? ?? const {}).forEach((k, v) => stamps[k as String] = (v as num).toInt());
    cards.forEach((k, c) {
      if (CardStatus.of(c).index >= CardStatus.familiar.index) firstKnown.putIfAbsent(k, () => unknownDate);
    });
  }

  Map<String, dynamic> _toJson() => {
        'starred': starred,
        'lists': lists,
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'reported': reported,
        'difficulty': difficulty.map((k, v) => MapEntry(k, v.name)),
        'cardFront': cardFront,
        'slowAudio': slowAudio,
        'orderByDrag': orderByDrag,
        'femaleVoice': femaleVoice,
        'toneHanzi': toneHanzi,
        'reminderOn': reminderOn,
        'reminderMinutes': reminderMinutes,
        'sessionSize': sessionSize,
        'dailyGoal': dailyGoal,
        'mixRelated': mixRelated,
        'practiceMode': practiceMode,
        'levels': (levels.toList()..sort()),
        'showSentences': showSentences,
        'journeyOn': journeyOn,
        'journeyAsked': journeyAsked,
        'journeyPaths': (journeyPaths.toList()..sort()),
        'journeyPace': journeyPace,
        'reviewEvery': reviewEvery,
        'milestoneColours': milestoneColours,
        'weeks': [for (final w in weeks) w.toJson()],
        'nextWeek': nextWeek?.toJson(),
        'recapPending': recapPending,
        'milestoneSeen': milestoneSeen,
        'sayItPlaces': sayItPlaces,
        'weekMix': weekMix,
        'weekSteps': weekSteps,
        'choiceKind': choiceKind,
        'widgetAnswersUpTo': widgetAnswersUpTo,
        'statsPeriod': statsPeriod,
        'reviews': [for (final r in reviews) r.toJson()],
        'speakTries': [for (final t in speakTries) t.toJson()],
        'soundTries': [for (final t in soundTries) t.toJson()],
        'talkRuns': [for (final t in talkRuns) t.toJson()],
        'snapshots': snapshots.map((k, v) => MapEntry(k, v.toJson())),
        'firstKnown': firstKnown.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch ~/ 1000)),
        'stamps': stamps,
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
    final data = backupData(text);
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
      for (final t in data['speakTries'] as List? ?? const []) {
        SpeakTry.fromJson(t as List);
      }
      for (final t in data['soundTries'] as List? ?? const []) {
        SoundTry.fromJson(t as List);
      }
      for (final t in data['talkRuns'] as List? ?? const []) {
        TalkRun.fromJson(t as Map);
      }
      (data['snapshots'] as Map? ?? const {}).forEach((k, v) => Snapshot.fromJson(v as List));
      (data['stamps'] as Map? ?? const {}).forEach((k, v) => (k as String, v as num));
      for (final w in data['weeks'] as List? ?? const []) {
        JourneyWeek.fromJson(w as Map<String, dynamic>);
      }
    } catch (_) {
      throw const FormatException('This backup file is damaged, so nothing was restored.');
    }
  }

  /// Joins another device's progress (the data in its sync file or backup)
  /// into this one, instead of replacing it like [importBackup]: every answer
  /// from both is kept, and for each star, list, card, score and report the
  /// side that changed it last wins. Settings stay as they are on this device.
  /// Throws [FormatException] if the data is damaged, and changes nothing then.
  Future<MergeResult> mergeFrom(Map<String, dynamic> data) async {
    _check(data);
    final theirStamps = <String, int>{
      for (final MapEntry(:key, :value) in (data['stamps'] as Map? ?? const {}).entries)
        key as String: (value as num).toInt(),
    };
    // Which side to believe for one thing: 1 theirs, -1 mine, 0 changed at the
    // same time (or never recorded), when both are kept where that makes sense.
    int side(String key) => (theirStamps[key] ?? 0).compareTo(stamps[key] ?? 0);
    void keepLatest(String key) {
      final t = theirStamps[key];
      if (t != null && t > (stamps[key] ?? 0)) stamps[key] = t;
    }

    Set<String> keysFrom(String prefix) => {
          for (final k in theirStamps.keys)
            if (k.startsWith(prefix)) k.substring(prefix.length),
        };

    // Stars, keeping this device's order and adding new ones at the end.
    final theirStarred = List<String>.from(data['starred'] as List? ?? const []);
    final theirStarSet = theirStarred.toSet();
    final myStarSet = starred.toSet();
    var starsAdded = 0, starsRemoved = 0;
    for (final id in {...theirStarred, ...starred, ...keysFrom('star:')}) {
      final s = side('star:$id');
      final want = s > 0
          ? theirStarSet.contains(id)
          : s < 0
              ? myStarSet.contains(id)
              : myStarSet.contains(id) || theirStarSet.contains(id);
      if (want && !myStarSet.contains(id)) {
        starred.add(id);
        starsAdded++;
      } else if (!want && myStarSet.contains(id)) {
        starred.remove(id);
        starsRemoved++;
      }
      keepLatest('star:$id');
    }
    // Keep the order the other device starred them in for the new ones.
    if (starsAdded > 0) {
      final order = {for (var i = 0; i < theirStarred.length; i++) theirStarred[i]: i};
      final kept = [for (final id in starred) if (myStarSet.contains(id)) id];
      final added = [for (final id in starred) if (!myStarSet.contains(id)) id]
        ..sort((a, b) => (order[a] ?? 0).compareTo(order[b] ?? 0));
      starred
        ..clear()
        ..addAll([...kept, ...added]);
    }

    // Lists: the newer list wins as a whole; changed at the same time, join them.
    final theirLists = <String, List<String>>{
      for (final MapEntry(:key, :value) in (data['lists'] as Map? ?? const {}).entries)
        key as String: List<String>.from(value as List),
    };
    for (final name in {...theirLists.keys, ...lists.keys, ...keysFrom('list:')}) {
      final s = side('list:$name');
      final theirs = theirLists[name];
      if (s > 0) {
        theirs == null ? lists.remove(name) : lists[name] = List.of(theirs);
      } else if (s == 0 && theirs != null) {
        final mine = lists.putIfAbsent(name, () => []);
        for (final id in theirs) {
          if (!mine.contains(id)) mine.add(id);
        }
      }
      keepLatest('list:$name');
    }
    final starSet = starred.toSet();
    for (final l in lists.values) {
      l.removeWhere((id) => !starSet.contains(id));
    }

    // Flashcards: the one answered last; never answered stamps, the one due later.
    var cardsUpdated = 0;
    (data['cards'] as Map? ?? const {}).forEach((k, v) {
      final key = k as String;
      final theirs = CardState.fromJson(v as Map<String, dynamic>);
      final mine = cards[key];
      final s = side('card:$key');
      final take = mine == null || s > 0 || (s == 0 && theirs.due.isAfter(mine.due));
      if (take && (mine == null || jsonEncode(mine.toJson()) != jsonEncode(theirs.toJson()))) {
        cards[key] = theirs;
        cardsUpdated++;
      }
      keepLatest('card:$key');
    });

    // Easy / OK / Hard scores and reported problems.
    void mergeMap<T>(String prefix, Map<String, T> mine, Map<String, T> theirs) {
      for (final id in {...theirs.keys, ...keysFrom(prefix)}) {
        final s = side('$prefix$id');
        if (s > 0 || (s == 0 && !mine.containsKey(id))) {
          final t = theirs[id];
          t == null ? mine.remove(id) : mine[id] = t;
        }
        keepLatest('$prefix$id');
      }
    }

    final theirDifficulty = <String, Difficulty>{
      for (final MapEntry(:key, :value) in (data['difficulty'] as Map? ?? const {}).entries)
        key as String: ?Difficulty.values.asNameMap()[value],
    };
    mergeMap('diff:', difficulty, theirDifficulty);
    mergeMap('report:', reported, Map<String, String>.from(data['reported'] as Map? ?? const {}));

    // Every answer from both, once each, in time order.
    final seen = {for (final r in reviews) jsonEncode(r.toJson())};
    var answersAdded = 0;
    for (final r in data['reviews'] as List? ?? const []) {
      final review = Review.fromJson(r as List);
      if (seen.add(jsonEncode(review.toJson()))) {
        reviews.add(review);
        answersAdded++;
      }
    }
    if (answersAdded > 0) {
      mergeSort(reviews, compare: (a, b) => a.at.compareTo(b.at));
      if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    }

    // Every Say it try from both, once each, in time order.
    final seenTries = {for (final t in speakTries) jsonEncode(t.toJson())};
    var triesAdded = 0;
    for (final t in data['speakTries'] as List? ?? const []) {
      final tr = SpeakTry.fromJson(t as List);
      if (seenTries.add(jsonEncode(tr.toJson()))) {
        speakTries.add(tr);
        triesAdded++;
      }
    }
    if (triesAdded > 0) {
      mergeSort(speakTries, compare: (a, b) => a.at.compareTo(b.at));
      if (speakTries.length > maxSpeakTries) speakTries.removeRange(0, speakTries.length - maxSpeakTries);
    }

    // Every Key sounds answer from both, once each, in time order.
    final seenSounds = {for (final t in soundTries) jsonEncode(t.toJson())};
    var soundsAdded = 0;
    for (final t in data['soundTries'] as List? ?? const []) {
      final tr = SoundTry.fromJson(t as List);
      if (seenSounds.add(jsonEncode(tr.toJson()))) {
        soundTries.add(tr);
        soundsAdded++;
      }
    }
    if (soundsAdded > 0) {
      mergeSort(soundTries, compare: (a, b) => a.at.compareTo(b.at));
      if (soundTries.length > maxSoundTries) soundTries.removeRange(0, soundTries.length - maxSoundTries);
    }

    // Every conversation from both, once each, in time order.
    final seenRuns = {for (final r in talkRuns) r.key};
    var runsAdded = 0;
    for (final t in data['talkRuns'] as List? ?? const []) {
      final run = TalkRun.fromJson(t as Map);
      if (seenRuns.add(run.key)) {
        talkRuns.add(run);
        runsAdded++;
      }
    }
    if (runsAdded > 0) {
      mergeSort(talkRuns, compare: (a, b) => a.at.compareTo(b.at));
      if (talkRuns.length > maxTalkRuns) talkRuns.removeRange(0, talkRuns.length - maxTalkRuns);
    }

    // Day-by-day counts this device doesn't have, and the earliest date each card became familiar.
    (data['snapshots'] as Map? ?? const {})
        .forEach((k, v) => snapshots.putIfAbsent(k as String, () => Snapshot.fromJson(v as List)));
    (data['firstKnown'] as Map? ?? const {}).forEach((k, v) {
      final theirs = DateTime.fromMillisecondsSinceEpoch((v as int) * 1000);
      final mine = firstKnown[k as String];
      if (mine == null || mine == unknownDate || (theirs != unknownDate && theirs.isBefore(mine))) {
        firstKnown[k] = theirs;
      }
    });

    // The journey's weeks: whichever device planned or changed them last.
    if (side('journey') > 0) {
      weeks
        ..clear()
        ..addAll([
          for (final w in data['weeks'] as List? ?? const []) JourneyWeek.fromJson(w as Map<String, dynamic>),
        ]);
      nextWeek = data['nextWeek'] == null ? null : JourneyWeek.fromJson(data['nextWeek'] as Map<String, dynamic>);
      if (weeks.isNotEmpty && !journeyAsked) {
        journeyOn = true;
        journeyAsked = true;
      }
    }
    keepLatest('journey');
    milestoneSeen = max(milestoneSeen, data['milestoneSeen'] as int? ?? 0);

    await _save();
    return MergeResult(
      answersAdded: answersAdded,
      starsAdded: starsAdded,
      starsRemoved: starsRemoved,
      cardsUpdated: cardsUpdated,
      triesAdded: triesAdded,
    );
  }

  /// The data part of a sync file or backup made by [exportBackup].
  /// Throws [FormatException] if [text] is not one.
  static Map<String, dynamic> backupData(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      throw const FormatException('This file is not a Language Library backup.');
    }
    if (j is! Map<String, dynamic> || j['format'] != backupFormat || j['data'] is! Map<String, dynamic>) {
      throw const FormatException('This file is not a Language Library backup.');
    }
    return j['data'] as Map<String, dynamic>;
  }

  Future<void> _save() async {
    _starredCache = null;
    _snapshot(DateTime.now());
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_toJson()));
  }

  /// About how much space the learner's own data takes on the phone.
  int get sizeBytes => utf8.encode(jsonEncode(_toJson())).length;

  bool isStarred(String id) => starred.contains(id);

  Future<void> toggleStar(String id) {
    _stamp('star:$id');
    if (starred.remove(id)) {
      lists.forEach((name, l) {
        if (l.remove(id)) _stamp('list:$name');
      });
    } else {
      starred.add(id);
    }
    return _save();
  }

  Future<void> createList(String name) {
    lists.putIfAbsent(name.trim(), () => []);
    _stamp('list:${name.trim()}');
    return _save();
  }

  Future<void> deleteList(String name) {
    lists.remove(name);
    _stamp('list:$name');
    return _save();
  }

  Future<void> setInList(String list, String id, bool inList) {
    final ids = lists.putIfAbsent(list, () => []);
    _stamp('list:$list');
    if (inList) {
      if (!ids.contains(id)) ids.add(id);
      if (!starred.contains(id)) {
        starred.add(id);
        _stamp('star:$id');
      }
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
    _stamp('card:${cardKey(id, d)}');
    return _save();
  }

  /// Saves a flashcard answer and logs it, with [spent] time on the card.
  Future<void> recordReview(String id, Direction d, CardState state, Rating rating, Duration spent, DateTime now) {
    final isNew = card(id, d) == null;
    cards[cardKey(id, d)] = state;
    _stamp('card:${cardKey(id, d)}', now);
    if (CardStatus.of(state).index >= CardStatus.familiar.index) firstKnown.putIfAbsent(cardKey(id, d), () => now);
    reviews.add(Review(now, spent > maxSpent ? maxSpent : spent, rating, isNew, id: id));
    if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    return _save();
  }

  /// Logs a multiple-choice or typing answer, which doesn't change when cards
  /// come back. [method] is how it was practised (see [Review.method]).
  Future<void> logAnswer(Rating rating, Duration spent, DateTime now, {required String method, String? id}) {
    reviews.add(Review(now, spent > maxSpent ? maxSpent : spent, rating, false, method: method, id: id));
    if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    return _save();
  }

  /// Keeps one conversation: its review, the scene's mark and Progress use it.
  Future<void> logTalkRun(TalkRun run) {
    talkRuns.add(run);
    if (talkRuns.length > maxTalkRuns) talkRuns.removeRange(0, talkRuns.length - maxTalkRuns);
    return _save();
  }

  /// Records one Key sounds answer.
  Future<void> logSoundTry(SoundTry t) {
    soundTries.add(t);
    if (soundTries.length > maxSoundTries) soundTries.removeRange(0, soundTries.length - maxSoundTries);
    return _save();
  }

  /// Records one Say it try at [id]: whether the recogniser heard it right.
  Future<void> logSpeakTry(String id, bool right, DateTime now) {
    speakTries.add(SpeakTry(now, id, right));
    if (speakTries.length > maxSpeakTries) speakTries.removeRange(0, speakTries.length - maxSpeakTries);
    return _save();
  }

  /// Adds answers given on the home-screen quiz widgets, logged as 'widget…',
  /// skipping any already brought in. Returns how many were added.
  Future<int> addWidgetAnswers(List<({String id, bool right, int at, int ms, String method})> answers) async {
    final fresh = [for (final a in answers) if (a.at > widgetAnswersUpTo) a]..sort((a, b) => a.at.compareTo(b.at));
    if (fresh.isEmpty) return 0;
    for (final a in fresh) {
      final spent = Duration(milliseconds: a.ms.clamp(0, maxSpent.inMilliseconds));
      final r = Review(DateTime.fromMillisecondsSinceEpoch(a.at), spent, a.right ? Rating.good : Rating.again, false,
          method: a.method, id: a.id);
      // Keep the log in time order for the statistics: answers in the app
      // since the widget answer go after it.
      var i = reviews.length;
      while (i > 0 && reviews[i - 1].at.isAfter(r.at)) {
        i--;
      }
      reviews.insert(i, r);
    }
    if (reviews.length > maxReviews) reviews.removeRange(0, reviews.length - maxReviews);
    widgetAnswersUpTo = fresh.last.at;
    await _save();
    return fresh.length;
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

  Future<void> setStatsPeriod(String v) {
    statsPeriod = v;
    return _save();
  }

  Future<void> setDailyGoal(int v) {
    dailyGoal = v;
    return _save();
  }

  Future<void> setSessionSize(int v) {
    sessionSize = v;
    return _save();
  }

  Future<void> setChoiceKind(String v) {
    choiceKind = v;
    return _save();
  }

  Future<void> setPracticeMode(String v) {
    practiceMode = v;
    return _save();
  }

  Future<void> setLevelShown(int level, bool on) {
    on ? levels.add(level) : levels.remove(level);
    return _save();
  }

  Future<void> setShowSentences(bool v) {
    showSentences = v;
    return _save();
  }

  /// Starts the journey or switches it off. The weeks planned so far are kept.
  Future<void> setJourneyOn(bool on, {int? milestone}) {
    journeyOn = on;
    journeyAsked = true;
    if (milestone != null) milestoneSeen = max(milestoneSeen, milestone);
    return _save();
  }

  Future<void> setJourneyPath(String path, bool on) {
    on ? journeyPaths.add(path) : journeyPaths.remove(path);
    if (journeyPaths.isEmpty) journeyPaths.add('connections');
    return _save();
  }

  Future<void> setJourneyPace(int v) {
    journeyPace = v;
    return _save();
  }

  Future<void> setReviewEvery(int v) {
    reviewEvery = v;
    return _save();
  }

  Future<void> setWeekMix(bool v) {
    weekMix = v;
    return _save();
  }

  /// Marks [id] done in the week-day step saved under [key] (see `stepKey`),
  /// forgetting other days' steps.
  Future<void> markStepDone(String key, String id) {
    final day = key.split('|').first;
    weekSteps.removeWhere((k, _) => !k.startsWith('$day|'));
    final done = weekSteps[key] ??= [];
    if (done.contains(id)) return Future.value();
    done.add(id);
    return _save();
  }

  Future<void> setMilestoneColours(bool v) {
    milestoneColours = v;
    return _save();
  }

  /// The week that [now] falls in, if one was planned.
  JourneyWeek? weekAt(DateTime now) {
    for (final w in weeks.reversed) {
      final end = DateTime(w.start.year, w.start.month, w.start.day + 7);
      if (!now.isBefore(w.start) && now.isBefore(end)) return w;
    }
    return null;
  }

  /// Adds [week], replacing a week that starts on the same day.
  /// [recapOf] marks a finished week whose recap is waiting to be seen.
  Future<void> startWeek(JourneyWeek week, {String? recapOf}) {
    weeks.removeWhere((w) => w.start == week.start);
    weeks.add(week);
    weeks.sort((a, b) => a.start.compareTo(b.start));
    if (weeks.length > maxWeeks) weeks.removeRange(0, weeks.length - maxWeeks);
    if (nextWeek != null && !nextWeek!.start.isAfter(week.start)) nextWeek = null;
    if (recapOf != null) recapPending = recapOf;
    _stamp('journey');
    return _save();
  }

  /// Picks the week to start next Monday.
  Future<void> setNextWeek(JourneyWeek? week) {
    nextWeek = week;
    _stamp('journey');
    return _save();
  }

  /// Adds a word to the week starting [start].
  Future<void> addToWeek(DateTime start, String id) {
    for (final w in weeks) {
      if (w.start == start && !w.words.contains(id)) w.words.add(id);
    }
    _stamp('journey');
    return _save();
  }

  Future<void> recapSeen() {
    recapPending = null;
    return _save();
  }

  /// Remembers that [list] (a Say it list that carries on) is at [nextId]
  /// today, or finished when [nextId] is null.
  Future<void> setSayItPlace(String day, String list, String? nextId) {
    sayItPlaces.removeWhere((k, _) => !k.startsWith('$day|'));
    final key = '$day|$list';
    nextId == null ? sayItPlaces.remove(key) : sayItPlaces[key] = nextId;
    return _save();
  }

  Future<void> setMilestoneSeen(int m) {
    milestoneSeen = m;
    return _save();
  }

  /// Stars every one of [ids] not starred yet, so their cards come back for review.
  Future<void> starAll(Iterable<String> ids) {
    for (final id in ids) {
      if (!starred.contains(id)) {
        starred.add(id);
        _stamp('star:$id');
      }
    }
    return _save();
  }

  Future<void> setMixRelated(bool v) {
    mixRelated = v;
    return _save();
  }

  Future<void> report(String id, String note) {
    reported[id] = note;
    _stamp('report:$id');
    return _save();
  }

  Future<void> clearReport(String id) {
    reported.remove(id);
    _stamp('report:$id');
    return _save();
  }

  /// Pass null to clear the score.
  Future<void> setDifficulty(String id, Difficulty? d) {
    _stamp('diff:$id');
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

  Future<void> setOrderByDrag(bool v) {
    orderByDrag = v;
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

/// What a sync brought in from the other device.
class MergeResult {
  const MergeResult(
      {this.answersAdded = 0, this.starsAdded = 0, this.starsRemoved = 0, this.cardsUpdated = 0, this.triesAdded = 0});
  final int answersAdded;
  final int starsAdded;
  final int starsRemoved;
  final int cardsUpdated;

  /// Say it tries.
  final int triesAdded;

  bool get changedAnything => answersAdded + starsAdded + starsRemoved + cardsUpdated + triesAdded > 0;

  /// For example "12 answers, 3 starred words and 8 flashcards from your other device".
  String describe() {
    String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
    final parts = [
      if (answersAdded > 0) n(answersAdded, 'answer', 'answers'),
      if (starsAdded > 0) n(starsAdded, 'starred word', 'starred words'),
      if (cardsUpdated > 0) n(cardsUpdated, 'flashcard', 'flashcards'),
      if (triesAdded > 0) n(triesAdded, 'Say it try', 'Say it tries'),
      if (starsRemoved > 0) n(starsRemoved, 'unstarred word', 'unstarred words'),
    ];
    if (parts.isEmpty) return 'Already up to date';
    final list = parts.length == 1 ? parts.first : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return 'Added $list from your other device';
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

/// One Say it try: when, which word, and whether the recogniser heard it right.
class SpeakTry {
  const SpeakTry(this.at, this.id, this.right);
  final DateTime at;
  final String id;
  final bool right;

  List<Object> toJson() => [at.millisecondsSinceEpoch, id, right ? 1 : 0];

  factory SpeakTry.fromJson(List j) =>
      SpeakTry(DateTime.fromMillisecondsSinceEpoch((j[0] as num).toInt()), j[1] as String, j[2] == 1);
}

/// One flashcard answer.
class Review {
  const Review(this.at, this.spent, this.rating, this.isNew, {this.method = 'cards', this.id});
  final DateTime at;
  final Duration spent;
  final Rating rating;

  /// The first time this card was ever answered.
  final bool isNew;

  /// How it was practised: 'cards', 'type', or a multiple-choice kind
  /// ('listen', 'meaning', 'reverse', 'pinyin'). Answers saved before this was
  /// recorded count as 'cards'.
  final String method;

  /// The word answered, when known (answers saved before it was recorded have none).
  final String? id;

  bool get right => rating != Rating.again;

  List<Object> toJson() => [
        at.millisecondsSinceEpoch ~/ 1000,
        spent.inMilliseconds,
        rating.index,
        isNew ? 1 : 0,
        if (id != null || method != 'cards') ...[method, ?id],
      ];

  factory Review.fromJson(List j) => Review(
        DateTime.fromMillisecondsSinceEpoch((j[0] as int) * 1000),
        Duration(milliseconds: j[1] as int),
        Rating.values[j[2] as int],
        j.length > 3 && j[3] == 1,
        method: j.length > 4 ? j[4] as String : 'cards',
        id: j.length > 5 ? j[5] as String : null,
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
