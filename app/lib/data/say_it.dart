import 'dart:math';

import '../models/entry.dart';
import 'daily.dart';
import 'library.dart';
import 'user_store.dart';

/// Words (or phrasebook sentences) for a round of "Say it": starred ones
/// first, then the easiest of what is switched on in Settings.
List<Entry> sayItQueue(Library lib, UserStore store, Random rnd, {required bool sentences, int count = 20}) {
  bool fits(Entry e) => sentences ? e.isSentence : !e.isSentence && e.simplified.length <= 4;
  final starred = [
    for (final id in store.starred)
      if (lib.byId[id] case final e? when fits(e)) e,
  ]..shuffle(rnd);
  final picked = {for (final e in starred) e.id};
  final rest = [
    for (final e in lib.entries)
      if (fits(e) && store.shows(e) && !picked.contains(e.id) && (sentences || e.curated || (e.hsk ?? 9) <= 2)) e,
  ]..shuffle(rnd);
  return [...starred, ...rest].take(count).toList();
}

/// How a word is going in Say it, from every try at it.
enum SpeakLevel {
  struggling('Struggling'),
  gettingThere('Getting there'),
  easy('Easy');

  const SpeakLevel(this.label);
  final String label;
}

/// One word's Say it record. A "round" runs from a try to the first try the
/// recogniser heard right, so [rounds] holds how many tries each success took.
class SpeakRecord {
  SpeakRecord(this.id);
  final String id;
  final List<int> rounds = [];

  /// Tries since the last success that haven't succeeded yet.
  int open = 0;
  int tries = 0;
  DateTime? last;

  int get successes => rounds.length;

  /// Tries per success, counting an unfinished round as at least as long as
  /// it has gone. Null before any success.
  double? get average {
    if (rounds.isEmpty) return null;
    final sum = rounds.reduce((a, b) => a + b) + open;
    return sum / rounds.length;
  }

  /// Null until there's enough to say: one success, or three misses in a row.
  SpeakLevel? get level {
    if (open >= 3) return SpeakLevel.struggling;
    final avg = average;
    if (avg == null) return null;
    if (avg >= 3) return SpeakLevel.struggling;
    if (avg <= 1.5 && rounds.last == 1 && open == 0) return SpeakLevel.easy;
    return SpeakLevel.gettingThere;
  }
}

/// Every word's record, from the try log (oldest first).
Map<String, SpeakRecord> speakRecords(List<SpeakTry> tries) {
  final out = <String, SpeakRecord>{};
  for (final t in tries) {
    final r = out.putIfAbsent(t.id, () => SpeakRecord(t.id));
    r.tries++;
    r.last = t.at;
    if (t.right) {
      r.rounds.add(r.open + 1);
      r.open = 0;
    } else {
      r.open++;
    }
  }
  return out;
}

/// The library words that make up [sentence], longest match first, as
/// (start index in its characters, word). Where a character has more than one
/// reading (了 le, liǎo), the word read the way the sentence reads it is used.
/// Characters with no word of their own are left out.
List<(int, Entry)> wordsIn(Entry sentence, Library lib) {
  final byHanzi = <String, List<Entry>>{};
  for (final e in lib.entries) {
    if (!e.isSentence) byHanzi.putIfAbsent(e.simplified, () => []).add(e);
  }
  final text = sentence.simplified;
  final reading = {
    for (final MapEntry(key: i, value: syl) in syllableAt(sentence).entries)
      i: sentence.syllables[syl].pinyin.toLowerCase(),
  };
  Entry? match(int at, int len) {
    final options = byHanzi[text.substring(at, at + len)];
    if (options == null) return null;
    final want = [for (var k = at; k < at + len; k++) reading[k]];
    for (final e in options) {
      final have = [for (final s in e.syllables) s.pinyin.toLowerCase()];
      if (have.length == len && [for (var k = 0; k < len; k++) have[k] == want[k]].every((b) => b)) return e;
    }
    return null;
  }

  final out = <(int, Entry)>[];
  var i = 0;
  while (i < text.length) {
    Entry? found;
    for (var len = min(4, text.length - i); len >= 1 && found == null; len--) {
      found = match(i, len);
    }
    if (found != null) {
      out.add((i, found));
      i += found.simplified.length;
    } else {
      i++;
    }
  }
  return out;
}

/// Character position in [e]'s text -> index of its syllable.
Map<int, int> syllableAt(Entry e) {
  final text = e.simplified;
  final out = <int, int>{};
  var syl = 0;
  for (var i = 0; i < text.length && syl < e.syllables.length; i++) {
    if (e.syllables[syl].hanzi == text[i]) out[i] = syl++;
  }
  return out;
}

/// Entries tried in Say it today -> whether the first try today was right.
Map<String, bool> sayItTriedToday(UserStore store, DateTime now) {
  final out = <String, bool>{};
  for (final t in store.speakTries) {
    if (t.at.year == now.year && t.at.month == now.month && t.at.day == now.day) out.putIfAbsent(t.id, () => t.right);
  }
  return out;
}

/// The key a carrying-on list is saved under: the same entries give the same
/// key, whatever order they're in.
String sayItListKey(List<Entry> entries) => ([for (final e in entries) e.id]..sort()).join(',');

/// Where a carrying-on round of [entries] opens today, after reordering them
/// with the ones tried today first: (the reordered list, where to start, the
/// first-try results of those tried today).
({List<Entry> queue, int at, Map<String, bool> tried}) sayItCarryOn(UserStore store, List<Entry> entries, DateTime now) {
  final today = sayItTriedToday(store, now);
  final done = [for (final e in entries) if (today.containsKey(e.id)) e];
  final rest = [for (final e in entries) if (!today.containsKey(e.id)) e];
  final queue = [...done, ...rest];
  var at = done.length;
  final next = store.sayItPlaces['${dayKey(now)}|${sayItListKey(entries)}'];
  if (next != null) {
    final i = queue.indexWhere((e) => e.id == next);
    // Gone from the list, or finished: past the end.
    at = i < 0 ? queue.length : max(i, at);
  }
  return (queue: queue, at: at, tried: {for (final e in done) e.id: today[e.id]!});
}
