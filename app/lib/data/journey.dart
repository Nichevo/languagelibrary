import 'dart:math';

import 'package:flutter/painting.dart' show Color;

import '../models/entry.dart';
import '../models/journey_week.dart';
import 'adapt.dart';
import 'daily.dart';
import 'families.dart';
import 'library.dart';
import 'today.dart';
import 'user_store.dart';

// The learning journey: weeks that grow out of the words the learner already
// has, by following the links the library data already holds (shared
// characters, phrasebook sentences, the dictionary's related words, topics and
// sentence patterns). Nothing here invents language facts; every suggestion
// carries the reasons it was picked.

/// Milestones: words known, whatever the source. A word is known when one of
/// its flashcards comes back in a week or more, or it was answered right 3 times
/// in a row on 2 days or more, whichever way it was practised.
const milestones = [150, 400, 900, 1800, 3000, 5000];
const milestoneNames = ['First sounds', 'Getting by', 'Small talk', 'Daily life', 'Telling stories', 'Reading freely'];

/// The app colour before the first milestone and after each one. The third is
/// the app's usual blue.
const milestoneColors = [
  Color(0xFF2E7D6B),
  Color(0xFF3F7D2E),
  Color(0xFF1565C0),
  Color(0xFFB2452A),
  Color(0xFF6A4FB3),
  Color(0xFF8A6A12),
  Color(0xFF00838F),
];
const usualColor = Color(0xFF1565C0);

/// How many milestones [known] words reach (0 to 6).
int milestoneFor(int known) => milestones.where((m) => known >= m).length;

/// The app's colour for [store]: the milestone colour, or the usual blue when
/// that is switched off or the journey isn't on.
Color appColor(Library lib, UserStore store) => store.journeyOn && store.milestoneColours
    ? milestoneColors[milestoneFor(knownWords(lib, store).length)]
    : usualColor;

/// Ids of words (not sentences) with a card the learner knows.
Set<String> knownWords(Library lib, UserStore store) =>
    {for (final id in knownIds(store)) if (lib.byId[id] case final e? when !e.isSentence) id};

/// Ids of words the learner has: starred, or practised on any card.
Set<String> yourWords(Library lib, UserStore store) {
  final out = <String>{};
  void add(String id) {
    if (lib.byId[id] case final e? when !e.isSentence) out.add(id);
  }

  store.starred.forEach(add);
  for (final k in store.cards.keys) {
    add(k.split(':').first);
  }
  return out;
}

const pathNames = {
  'connections': 'Connections',
  'topics': 'Topics',
  'characters': 'Characters',
  'sentences': 'Sentences',
  'hsk': 'HSK gaps',
  'review': 'Review',
};

const pathDescriptions = {
  'connections': 'Grow from what you know and what you found yourself',
  'topics': 'Take turns through Food, Travel, Family, Love and more',
  'characters': 'One character family a week',
  'sentences': 'One sentence pattern a week, with words that fit it',
  'hsk': 'Fill in the HSK words you are missing',
};

/// Characters, lookups that don't change while the app runs.
class _Index {
  _Index(Library lib) {
    for (final e in lib.entries) {
      if (e.isSentence) {
        final parts = [
          for (final r in e.related)
            if (lib.byId[r.id] case final w? when !w.isSentence) w.id,
        ];
        if (parts.isEmpty) continue;
        sentenceParts[e.id] = parts;
        for (final p in parts) {
          (wordSentences[p] ??= []).add(e.id);
        }
      } else {
        for (final c in chars(e.simplified)) {
          (byChar[c] ??= []).add(e);
        }
      }
    }
  }

  final byChar = <String, List<Entry>>{};
  final sentenceParts = <String, List<String>>{};
  final wordSentences = <String, List<String>>{};

  static final _cache = Expando<_Index>();
  static _Index of(Library lib) => _cache[lib] ??= _Index(lib);
}

/// The distinct Chinese characters in [s], in order.
List<String> chars(String s) => {
      for (final c in s.runes.map(String.fromCharCode))
        if (RegExp(r'[㐀-鿿]').hasMatch(c)) c,
    }.toList();

/// A word worth learning next, with why.
class Suggestion {
  Suggestion(this.entry, this.score, this.reasons, {this.finishes = 0});
  final Entry entry;
  final double score;
  final List<String> reasons;

  /// Phrasebook sentences it is the only missing word of.
  final int finishes;
}

/// A phrasebook sentence the learner has every word of but one.
typedef AlmostReadable = ({Entry sentence, Entry missing});

/// The links between the learner's words and the rest of the library.
class Connections {
  Connections(this.lib, this.store) : _ix = _Index.of(lib) {
    yours = yourWords(lib, store);
    known = knownWords(lib, store);
    for (final id in yours) {
      for (final c in chars(lib.byId[id]!.simplified)) {
        (yourByChar[c] ??= []).add(id);
      }
    }
    for (final MapEntry(key: s, value: parts) in _ix.sentenceParts.entries) {
      final missing = [for (final p in parts) if (!yours.contains(p)) p];
      if (missing.length == 1) (_finishes[missing.single] ??= []).add(s);
    }
  }

  final Library lib;
  final UserStore store;
  final _Index _ix;
  late final Set<String> yours;
  late final Set<String> known;

  /// Character -> the learner's words that have it.
  final yourByChar = <String, List<String>>{};
  final _finishes = <String, List<String>>{};

  /// Every word the library has with character [c].
  List<Entry> wordsWith(String c) => _ix.byChar[c] ?? const [];

  /// Sentence ids that use word [id].
  List<String> sentencesWith(String id) => _ix.wordSentences[id] ?? const [];

  /// How well [e] links to the learner's words, and why.
  Suggestion score(Entry e) {
    final reasons = <String>[];
    var score = 0.0;
    final cs = chars(e.simplified);
    final shared = [for (final c in cs) if (yourByChar.containsKey(c)) c];
    if (shared.isNotEmpty) {
      if (cs.length == 1) {
        final inWord = lib.byId[yourByChar[cs.single]!.first]!.simplified;
        reasons.add('you know it from $inWord');
        score += 1.5;
      } else {
        reasons.add('you know ${shared.join(' + ')}');
        score += 2 * shared.length / cs.length;
      }
    }
    final fin = _finishes[e.id]?.length ?? 0;
    if (fin > 0) {
      reasons.add('finishes $fin ${fin == 1 ? 'sentence' : 'sentences'}');
      score += 1.2 * min(fin, 3);
    }
    final links = [
      for (final r in e.related)
        if (yours.contains(r.id) && !r.why.startsWith('Opposite')) lib.byId[r.id]!,
    ];
    final opposite = [
      for (final r in e.related)
        if (yours.contains(r.id) && r.why.startsWith('Opposite')) lib.byId[r.id]!,
    ];
    if (opposite.isNotEmpty) {
      reasons.add('opposite of ${opposite.first.simplified}');
      score += 0.8;
    } else if (links.isNotEmpty) {
      reasons.add('linked to ${links.first.simplified}');
      score += 0.5 * min(links.length, 2);
    }
    // A little towards the commoner (lower level) words.
    score += e.hsk == null ? 0.2 : max(0, 0.6 - 0.1 * e.hsk!);
    return Suggestion(e, score, reasons, finishes: fin);
  }

  /// Words the learner doesn't have yet, most connected first. Only words
  /// switched on in Settings, unless [any] is set.
  List<Suggestion> suggestions({bool Function(Entry)? where, int limit = 30, bool any = false, Set<String>? skip}) {
    final out = <Suggestion>[];
    for (final e in lib.entries) {
      if (e.isSentence || yours.contains(e.id) || (skip?.contains(e.id) ?? false)) continue;
      if (!any && !store.shows(e)) continue;
      if (where != null && !where(e)) continue;
      final s = score(e);
      if (where == null && s.reasons.isEmpty) continue;
      out.add(s);
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.entry.simplified.length.compareTo(b.entry.simplified.length);
    });
    return out.take(limit).toList();
  }

  /// Phrasebook sentences the learner has every word of but one, shortest first.
  List<AlmostReadable> almostReadable({int limit = 10, Set<String>? only}) {
    final out = <AlmostReadable>[];
    for (final MapEntry(key: w, value: ss) in _finishes.entries) {
      if (only != null && !only.contains(w)) continue;
      final missing = lib.byId[w]!;
      for (final s in ss) {
        out.add((sentence: lib.byId[s]!, missing: missing));
      }
    }
    out.sort((a, b) => a.sentence.simplified.length.compareTo(b.sentence.simplified.length));
    return out.take(limit).toList();
  }
}

/// Words first answered or starred in [from, to): the ones the learner found
/// for themselves rather than from the week's plan.
List<String> foundBetween(Library lib, UserStore store, DateTime from, DateTime to, {Set<String> except = const {}}) {
  final firstSeen = <String, DateTime>{};
  for (final r in store.reviews) {
    final id = r.id;
    if (id != null) firstSeen.putIfAbsent(id, () => r.at);
  }
  final out = <String>[];
  bool inRange(DateTime t) => !t.isBefore(from) && t.isBefore(to);
  for (final id in {...firstSeen.keys, ...store.starred}) {
    final e = lib.byId[id];
    if (e == null || e.isSentence || except.contains(id)) continue;
    final starredAt = store.isStarred(id) ? store.stamps['star:$id'] : null;
    final first = firstSeen[id];
    final starTime = starredAt == null ? null : DateTime.fromMillisecondsSinceEpoch(starredAt);
    // Counts in the range only if this is when the learner first took it up.
    final earliest = [?first, ?starTime].fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (earliest != null && inRange(earliest)) out.add(id);
  }
  return out;
}

/// Monday midnight of the week [t] is in.
DateTime mondayOf(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

/// The practice type used least in the week before [now].
String leastUsedSkill(UserStore store, DateTime now) {
  final since = now.subtract(const Duration(days: 7));
  final counts = {for (final m in todayTypes) m: 0};
  for (final r in store.reviews) {
    final m = r.method == 'opposite' ? 'order' : r.method;
    if (!r.at.isBefore(since) && counts.containsKey(m)) counts[m] = counts[m]! + 1;
  }
  var best = 'speak';
  for (final m in ['speak', 'tones', 'build', 'order']) {
    if (counts[m]! < counts[best]!) best = m;
  }
  return best;
}

/// The path the next week takes: the switched-on paths in turn, with a review
/// week every [UserStore.reviewEvery] weeks.
String nextPath(UserStore store) {
  final n = store.weeks.length + 1;
  if (store.reviewEvery > 0 && n % store.reviewEvery == 0 && store.weeks.isNotEmpty) return 'review';
  final paths = [for (final p in pathNames.keys) if (store.journeyPaths.contains(p)) p];
  if (paths.isEmpty) return 'connections';
  final planned = store.weeks.where((w) => !w.isReview).length;
  return paths[planned % paths.length];
}

/// Plans a week starting [start] along [path], or null when that path has
/// nothing left to offer. [seed] makes a connections week grow from that word.
/// The week's Sentences level and its new words and practice types come from
/// how last week went (see data/adapt.dart).
JourneyWeek? planWeek(Library lib, UserStore store, DateTime start, String path,
    {String? seed, String? char, Connections? conn}) {
  final adapt = adaptFor(store, start);
  final w = _planWeek(lib, store, start, path, seed: seed, char: char, conn: conn, paceFor: adapt?.pace);
  return w == null ? null : withSentenceLevel(lib, store, w).copyWith(adapt: () => adapt);
}

/// [week] adjusted afresh to how the week before it went: a week picked
/// before last week was over gets the latest adjustments, keeping at most the
/// new number of words.
JourneyWeek withAdjustments(Library lib, UserStore store, JourneyWeek week) {
  final adapt = adaptFor(store, week.start);
  final words = adapt != null && week.words.length > adapt.pace ? week.words.sublist(0, adapt.pace) : null;
  return withSentenceLevel(lib, store, week).copyWith(adapt: () => adapt, words: words);
}

/// Plans the picked next week again, for example after the recap's "how did
/// it feel?" changed how many words it gets.
Future<void> replanNext(Library lib, UserStore store) async {
  final nw = store.nextWeek;
  if (nw == null) return;
  final again = planWeek(lib, store, nw.start, nw.path, seed: nw.seed, char: nw.char);
  if (again != null) await store.setNextWeek(again);
}

/// [week] with its Sentences level worked out afresh from the week before it.
JourneyWeek withSentenceLevel(Library lib, UserStore store, JourneyWeek week) {
  final (level, note) = sentenceLevel(lib, store, week.start);
  return week.copyWith(level: level, levelNote: () => note);
}

JourneyWeek? _planWeek(Library lib, UserStore store, DateTime start, String path,
    {String? seed, String? char, Connections? conn, int? paceFor}) {
  final c = conn ?? Connections(lib, store);
  final pace = paceFor ?? store.journeyPace;
  final skill = leastUsedSkill(store, start);
  final used = {for (final w in store.weeks) ...w.words};
  final recent = store.weeks.length > 6 ? store.weeks.sublist(store.weeks.length - 6) : store.weeks;
  List<String> ids(List<Suggestion> s) => [for (final x in s) x.entry.id];

  switch (path) {
    case 'review':
      // Words answered wrong lately, then earlier weeks' words not known yet.
      final since = start.subtract(const Duration(days: 28));
      final misses = <String, int>{};
      for (final r in store.reviews) {
        final id = r.id;
        if (id == null || r.at.isBefore(since) || r.right) continue;
        if (lib.byId[id] case final e? when !e.isSentence) misses[id] = (misses[id] ?? 0) + 1;
      }
      final words = (misses.keys.toList()..sort((a, b) => misses[b]!.compareTo(misses[a]!))).take(pace).toList();
      for (final w in recent.reversed) {
        for (final id in w.words) {
          if (words.length >= pace) break;
          if (!c.known.contains(id) && !words.contains(id)) words.add(id);
        }
      }
      if (words.isEmpty) return null;
      return JourneyWeek(
          start: start, path: path, title: 'Review week', why: 'No new words: the ones that tripped you up, and earlier weeks\' words', words: words, skill: 'order');

    case 'topics':
      final usedTopics = [for (final w in recent) ?w.topic];
      final options = [for (final t in Library.topics) if (t != 'everyday') t]
        ..sort((a, b) => usedTopics.lastIndexOf(a).compareTo(usedTopics.lastIndexOf(b)));
      for (final t in [...options, 'everyday']) {
        final words = ids(c.suggestions(where: (e) => e.topics.contains(t), limit: pace, skip: used));
        if (words.length < min(5, pace)) continue;
        final name = _topicName(t);
        return JourneyWeek(
            start: start, path: path, title: name, why: '$name words that link to ones you know', words: words, skill: skill, topic: t);
      }
      return null;

    case 'characters':
      final usedChars = {for (final w in store.weeks) ?w.char};
      final options = c.yourByChar.entries.where((m) => char != null ? m.key == char : !usedChars.contains(m.key)).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final MapEntry(key: ch) in options) {
        final words = ids(c.suggestions(where: (e) => e.simplified.contains(ch), limit: pace, skip: used));
        if (words.length < (char != null ? 1 : min(4, pace))) continue;
        return JourneyWeek(
            start: start,
            path: path,
            title: 'The $ch family',
            why: 'You know $ch from ${c.yourByChar[ch]!.length} words. These use it too',
            words: words,
            skill: skill,
            char: ch);
      }
      return null;

    case 'sentences':
      final usedPatterns = {for (final w in store.weeks) ?w.pattern};
      for (final p in lib.patterns) {
        if (usedPatterns.contains(p.id)) continue;
        final words = <String>[];
        for (final x in p.examples) {
          for (final id in c._ix.sentenceParts[x.sentence.id] ?? const <String>[]) {
            if (!c.yours.contains(id) && !words.contains(id) && words.length < pace) words.add(id);
          }
        }
        if (words.length < pace) {
          words.addAll(ids(c.suggestions(limit: pace - words.length, skip: {...used, ...words})));
        }
        if (words.isEmpty) continue;
        return JourneyWeek(
            start: start, path: path, title: p.name, why: 'A sentence pattern, with the words its examples need', words: words, skill: 'build', pattern: p.id);
      }
      return null;

    case 'hsk':
      for (final level in lib.levels) {
        final words = ids(c.suggestions(where: (e) => e.hsk == level, limit: pace, skip: used, any: true));
        if (words.length < min(5, pace)) continue;
        return JourneyWeek(
            start: start, path: path, title: 'HSK $level gaps', why: 'HSK $level words you don\'t have yet, most connected first', words: words, skill: skill);
      }
      return null;

    default: // 'connections'
      Entry? seedEntry = seed == null ? null : lib.byId[seed];
      if (seedEntry == null) {
        // Something the learner found for themselves lately, the best linked.
        final found = foundBetween(lib, store, start.subtract(const Duration(days: 14)), start.add(const Duration(days: 7)),
            except: used);
        var best = -1;
        for (final id in found) {
          final e = lib.byId[id]!;
          final n = chars(e.simplified).fold(0, (s, ch) => s + c.wordsWith(ch).where((w) => !c.yours.contains(w.id)).length);
          if (n > best) {
            best = n;
            seedEntry = e;
          }
        }
      }
      seedEntry ??= c.suggestions(limit: 1, skip: used).firstOrNull?.entry;
      if (seedEntry == null) return null;
      final s = seedEntry;
      final seedChars = chars(s.simplified).toSet();
      final related = {for (final r in s.related) r.id};
      final pool = c.suggestions(limit: 400, skip: {...used, s.id});
      double near(Suggestion x) =>
          x.score +
          (chars(x.entry.simplified).any(seedChars.contains) ? 2 : 0) +
          (related.contains(x.entry.id) ? 1 : 0) +
          (x.entry.topics.any(s.topics.contains) && !x.entry.topics.contains('everyday') ? 0.5 : 0);
      pool.sort((a, b) => near(b).compareTo(near(a)));
      final words = [if (!c.yours.contains(s.id)) s.id, ...ids(pool)].take(pace).toList();
      final topic = s.topics.where((t) => t != 'everyday').firstOrNull;
      return JourneyWeek(
          start: start,
          path: 'connections',
          title: 'Grows from ${s.simplified}',
          why: '${s.simplified} (${s.meanings.first}) and words that link to it',
          words: words,
          skill: skill,
          seed: s.id,
          topic: topic);
  }
}

String _topicName(String t) => '${t[0].toUpperCase()}${t.substring(1)}';

/// The suggested next week first, then one from each other switched-on path,
/// for the learner to pick from. All start on [start].
List<JourneyWeek> weekOptions(Library lib, UserStore store, DateTime start, {int count = 3}) {
  final conn = Connections(lib, store);
  final first = nextPath(store);
  final out = <JourneyWeek>[];
  void tryPath(String p, {String? seed}) {
    if (out.length >= count) return;
    final w = planWeek(lib, store, start, p, conn: conn, seed: seed);
    if (w != null && !out.any((o) => o.title == w.title)) out.add(w);
  }

  tryPath(first);
  for (final p in pathNames.keys) {
    if (p != 'review' && store.journeyPaths.contains(p)) tryPath(p);
  }
  // Fill up with paths that aren't switched on, so there is always a choice.
  for (final p in ['connections', 'topics', 'characters']) {
    tryPath(p);
  }
  return out;
}

/// Makes sure the current week exists once the journey is on: the week picked
/// in advance, or else the suggested one. Returns true when it started a week.
Future<bool> ensureWeek(Library lib, UserStore store, DateTime now) async {
  if (!store.journeyOn || store.weekAt(now) != null) return false;
  final start = mondayOf(now);
  final picked = store.nextWeek;
  final chosen = picked != null && !picked.start.isAfter(start)
      ? picked.copyWith(start: start)
      : weekOptions(lib, store, start, count: 1).firstOrNull;
  if (chosen == null) return false;
  // A week picked early may have been planned before last week was over.
  final week = withAdjustments(lib, store, chosen);
  final last = store.weeks.lastOrNull;
  await store.startWeek(week, recapOf: last != null && picked == null ? dayKey(last.start) : null);
  return true;
}

/// One day of a week's plan.
enum DayKind { meet, practise, skill, sentences, recap }

class DayPlan {
  const DayPlan(this.kind, this.title, this.detail, this.ids);
  final DayKind kind;
  final String title, detail;

  /// The words the day works on.
  final List<String> ids;
}

/// What day [day] (0 = Monday) of [week] is for.
DayPlan dayPlan(JourneyWeek week, int day, {String? skillTitle}) {
  final w = week.words;
  final half = (w.length + 1) ~/ 2;
  if (week.isReview) {
    return day == 6
        ? DayPlan(DayKind.recap, 'Week recap', 'A look back, and pick next week', w)
        : DayPlan(DayKind.practise, 'Review', 'Go over the words that need it', w);
  }
  return switch (day) {
    0 => DayPlan(DayKind.meet, 'Meet $half new words', 'Flashcards for the first half of the week\'s words', w.sublist(0, half)),
    1 => DayPlan(DayKind.meet, 'Meet ${w.length - half} more', 'Flashcards for the rest of the week\'s words', w.sublist(half)),
    2 => DayPlan(DayKind.practise, 'Practise the week\'s words', 'Every word of the week, due or not', w),
    3 => DayPlan(DayKind.skill, '${skillTitle ?? 'Skill'} day', 'The week\'s practice type, with its words where it can', w),
    4 => DayPlan(DayKind.practise, 'Mixed review', 'All the week\'s words again', w),
    5 => DayPlan(DayKind.sentences, 'Sentences', 'Say ${sentenceAim(week)} phrasebook sentences with the week\'s words, or more if you like', w),
    _ => DayPlan(DayKind.recap, 'Week recap', 'A look back, and pick next week', w),
  };
}

/// The week's words the learner has started on: a flashcard, a Say it try or
/// an answer of any kind.
Set<String> metIn(UserStore store, JourneyWeek week) {
  final words = week.words.toSet();
  return {
    for (final k in store.cards.keys)
      if (words.contains(k.split(':').first)) k.split(':').first,
    for (final t in store.speakTries)
      if (words.contains(t.id)) t.id,
    for (final r in store.reviews)
      if (r.id case final id? when words.contains(id)) id,
  };
}

/// The Say it list a day of [week] works through, when it has one: the
/// Sentences day's sentences, or the week's words on a Say it skill day.
List<Entry>? sayItListFor(Library lib, JourneyWeek week, DayKind kind) => switch (kind) {
      DayKind.sentences => () {
          final ss = sentencesFor(lib, week.words, limit: sentencesInWeek, level: week.level);
          return ss.isEmpty ? null : ss;
        }(),
      // Say it is hard work: never more than [hardCap] words a day.
      DayKind.skill when week.skill == 'speak' => [for (final id in week.words.take(hardCap)) ?lib.byId[id]],
      _ => null,
    };

/// How many sentences the Sentences day asks you to say.
const sentencesPerDay = 10;

/// The Sentences day works through up to this many of the week's sentences,
/// carrying on from the last one, so a day that's done can keep going.
const sentencesInWeek = 40;

/// How many sentences the Sentences day of [week] asks for: 10 at the usual
/// level, 2 fewer for each step easier and 2 more for each step harder.
int sentenceAim(JourneyWeek week) => sentencesPerDay + 2 * week.level;

/// Phrasebook sentences that use any of [ids], easiest first: fewest
/// characters, with 2 more counted for each other word in the sentence.
///
/// [level] below 0 keeps to the easier half (-1) or third (-2); above 0 it
/// leaves out the easiest fifth for each step. Either way only when enough are
/// left to fill a day. The order doesn't depend on what the learner knows, so
/// a week's list stays the same all week and Say it can carry on in it.
List<Entry> sentencesFor(Library lib, Iterable<String> ids, {int limit = 20, int level = 0}) {
  final ix = _Index.of(lib);
  final words = ids.toSet();
  final out = <Entry>{};
  for (final id in words) {
    for (final s in ix.wordSentences[id] ?? const <String>[]) {
      out.add(lib.byId[s]!);
    }
  }
  int effort(Entry e) =>
      _hanCount(e.simplified) + 2 * (ix.sentenceParts[e.id] ?? const <String>[]).where((p) => !words.contains(p)).length;
  final score = {for (final e in out) e: effort(e)};
  var list = out.toList()
    ..sort((a, b) {
      final c = score[a]!.compareTo(score[b]!);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final aim = sentencesPerDay + 2 * level;
  if (level < 0) {
    final keep = (list.length / (level == -1 ? 2 : 3)).ceil();
    if (keep >= aim) list = list.sublist(0, keep);
  } else if (level > 0) {
    final drop = (list.length * 0.2 * level).floor();
    if (list.length - drop >= aim) list = list.sublist(drop);
  }
  return list.take(limit).toList();
}

int _hanCount(String s) => s.runes.where((r) => r >= 0x3400 && r <= 0x9fff).length;

/// How the Say it sentences between [from] and [to] went: how many were said
/// (first try at each sentence each day) and how many of those the recogniser
/// understood.
({int said, int right}) sentenceResults(Library lib, UserStore store, DateTime from, DateTime to) {
  final seen = <String>{};
  var said = 0, right = 0;
  for (final t in store.speakTries) {
    if (t.at.isBefore(from) || !t.at.isBefore(to)) continue;
    if (lib.byId[t.id] case final e? when e.isSentence) {
      if (!seen.add('${dayKey(t.at)}|${t.id}')) continue;
      said++;
      if (t.right) right++;
    }
  }
  return (said: said, right: right);
}

/// The Sentences level for a week starting [start], and a note when it moved:
/// one step easier when under 40% of last week's sentences were understood,
/// one step harder when over 80% were. Fewer than 5 said keeps the level.
(int, String?) sentenceLevel(Library lib, UserStore store, DateTime start) {
  final prev = store.weeks.where((w) => w.start.isBefore(start)).lastOrNull;
  final was = prev?.level ?? 0;
  final r = sentenceResults(lib, store, DateTime(start.year, start.month, start.day - 7), start);
  if (r.said < 5) return (was, null);
  final heard = 'Last week the recogniser understood ${r.right} of ${r.said} sentences';
  if (r.right * 10 < r.said * 4) {
    return was > -2
        ? (was - 1, '$heard, so this week\'s are a bit shorter and there are fewer')
        : (was, '$heard, so this week\'s stay short');
  }
  if (r.right * 10 > r.said * 8) {
    return was < 2
        ? (was + 1, '$heard, so this week\'s are a bit longer and there are more')
        : (was, '$heard, so this week\'s stay at the hardest level');
  }
  return (was, null);
}

/// How a week went.
class WeekSummary {
  WeekSummary({
    required this.met,
    required this.planned,
    required this.found,
    required this.answers,
    required this.checked,
    required this.right,
    required this.days,
  });

  /// [answers] counts every answer, flashcards too. [right] is out of
  /// [checked]: the answers the app checked (flashcards are marked by the
  /// learner, so they are left out).
  final int met, planned, answers, checked, right, days;
  final List<String> found;
  int get percentRight => checked == 0 ? 0 : (100 * right / checked).round();
}

WeekSummary summarise(Library lib, UserStore store, JourneyWeek week, DateTime now) {
  final end = DateTime(week.start.year, week.start.month, week.start.day + 7);
  final to = now.isBefore(end) ? now.add(const Duration(seconds: 1)) : end;
  final met = metIn(store, week).length;
  var answers = 0, checked = 0, right = 0;
  final days = <int>{};
  for (final r in store.reviews) {
    if (r.at.isBefore(week.start) || !r.at.isBefore(to)) continue;
    answers++;
    days.add(dayNumber(r.at));
    if (r.method == 'cards') continue;
    checked++;
    if (r.right) right++;
  }
  return WeekSummary(
    met: met,
    planned: week.words.length,
    found: foundBetween(lib, store, week.start, to, except: week.words.toSet()),
    answers: answers,
    checked: checked,
    right: right,
    days: days.length,
  );
}

/// One cluster of the word web: a character and the learner's words around it.
class Cluster {
  Cluster(this.hanzi, this.words, this.next);
  final String hanzi;
  final List<String> words;

  /// A few words that would join this cluster next.
  final List<Suggestion> next;
}

/// The learner's words grouped by the characters they share: up to [max]
/// clusters, biggest first. Each word sits in the biggest cluster it belongs to.
List<Cluster> wordWeb(Connections c, {int max = 9, int nextPer = 3}) {
  final sizes = {for (final MapEntry(:key, :value) in c.yourByChar.entries) key: value.length};
  final hubs = (sizes.keys.where((k) => sizes[k]! >= 2).toList()..sort((a, b) => sizes[b]!.compareTo(sizes[a]!)))
      .take(max)
      .toList();
  final groups = {for (final h in hubs) h: <String>[]};
  for (final id in c.yours) {
    final cs = chars(c.lib.byId[id]!.simplified);
    final hub = hubs.where(cs.contains).firstOrNull;
    if (hub != null) groups[hub]!.add(id);
  }
  return [
    for (final h in hubs)
      if (groups[h]!.isNotEmpty)
        Cluster(h, groups[h]!, c.suggestions(where: (e) => e.simplified.contains(h), limit: nextPer)),
  ];
}

/// For each HSK level: (level, known, all words at that level).
List<(int, int, int)> hskCoverage(Library lib, Set<String> known) => [
      for (final l in lib.levels)
        (
          l,
          known.where((id) => lib.byId[id]?.hsk == l).length,
          lib.entries.where((e) => e.hsk == l && !e.isSentence).length,
        ),
    ];
