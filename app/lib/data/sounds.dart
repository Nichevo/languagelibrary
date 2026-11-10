import 'dart:math';

import '../models/entry.dart';
import 'library.dart';

/// Shown on the Tricky sounds screens: the groups are worked out by the app,
/// the words, pinyin and meanings are not.
const soundsSourceNote = 'Grouped by this app from the pinyin. Words, pinyin and meanings from HSK and CC-CEDICT. '
    'Which extra characters were added to fill the tone sets is our choice.';

/// One syllable said with different tones, each a different word:
/// tāng 汤 soup, táng 糖 sugar, tǎng 躺 to lie down, tàng 烫 hot.
class ToneSet {
  ToneSet(this.syllable, this.byTone);

  /// The syllable without its tone, as in the numbered pinyin ("tang", "lü").
  final String syllable;

  /// Tone (1 to 4) -> the word picked for it.
  final Map<int, Entry> byTone;

  List<Entry> get words => [for (final t in byTone.keys.toList()..sort()) byTone[t]!];
}

/// Characters said the same way, tone and all: shì 是 事 试 市.
class SameSound {
  SameSound(this.pinyin, this.words);
  final String pinyin;
  final List<Entry> words;
}

/// One character with more than one reading: 长 cháng long, zhǎng to grow.
class TwoSounds {
  TwoSounds(this.hanzi, this.readings);
  final String hanzi;
  final List<Entry> readings;
}

/// A tone change rule, with library words it applies to.
class ToneRule {
  ToneRule(this.note, this.words);

  /// The rule as the word pages show it ("不 changes to bú before a 4th tone").
  final String note;
  final List<Entry> words;
}

/// The single-syllable, single-character words with a full tone (1 to 4).
Iterable<(String, int, Entry)> _oneSyllable(Library lib) sync* {
  for (final e in lib.entries) {
    if (e.isSentence || e.simplified.runes.length != 1 || e.syllables.length != 1) continue;
    final p = e.pinyinNumbered.trim().toLowerCase();
    final tone = int.tryParse(p.substring(p.length - 1));
    if (tone == null || tone < 1 || tone > 4) continue;
    yield (p.substring(0, p.length - 1), tone, e);
  }
}

/// HSK words come before the added ones, and lower levels first.
int _rank(Entry e) => e.hsk ?? 10;

int _setRank(Entry e) => (e.polyphonic ? 100 : 0) + _rank(e);

final _setsCache = Expando<List<ToneSet>>();

/// The tone set [e] is shown in, if any.
ToneSet? toneSetFor(Library lib, Entry e) {
  for (final s in toneSets(lib)) {
    if (s.byTone.values.any((w) => w.id == e.id)) return s;
  }
  return null;
}

/// Syllables that make at least [minTones] different words by tone alone,
/// four-tone sets first, then the ones with the easiest words.
List<ToneSet> toneSets(Library lib, {int minTones = 3}) =>
    minTones == 3 ? (_setsCache[lib] ??= _toneSets(lib, 3)) : _toneSets(lib, minTones);

List<ToneSet> _toneSets(Library lib, int minTones) {
  final groups = <String, Map<int, Entry>>{};
  for (final (syl, tone, e) in _oneSyllable(lib)) {
    final g = groups.putIfAbsent(syl, () => {});
    final have = g[tone];
    // A character with several readings is a poor example of a tone: pick another if there is one.
    if (have == null || _setRank(e) < _setRank(have)) g[tone] = e;
  }
  final sets = [
    for (final MapEntry(:key, :value) in groups.entries)
      if (value.length >= minTones) ToneSet(key, value),
  ];
  double ease(ToneSet s) => s.byTone.values.fold<int>(0, (t, e) => t + _rank(e)) / s.byTone.length;
  sets.sort((a, b) {
    final c = b.byTone.length.compareTo(a.byTone.length);
    return c != 0 ? c : ease(a).compareTo(ease(b));
  });
  return sets;
}

/// Groups of at least [minWords] HSK characters with exactly the same sound,
/// biggest first. Only HSK levels up to [maxLevel], so the groups stay useful.
List<SameSound> sameSounds(Library lib, {int minWords = 3, int maxLevel = 4}) {
  final groups = <String, List<Entry>>{};
  final seen = <String>{};
  for (final (_, _, e) in _oneSyllable(lib)) {
    final hsk = e.hsk;
    if (hsk == null || hsk > maxLevel) continue;
    // One entry per character and sound.
    if (!seen.add('${e.simplified}${e.pinyinNumbered}')) continue;
    groups.putIfAbsent(e.pinyin, () => []).add(e);
  }
  final out = [
    for (final MapEntry(:key, :value) in groups.entries)
      if ({for (final e in value) e.simplified}.length >= minWords) SameSound(key, value..sort((a, b) => _rank(a).compareTo(_rank(b)))),
  ]..sort((a, b) {
      final c = b.words.length.compareTo(a.words.length);
      return c != 0 ? c : a.pinyin.compareTo(b.pinyin);
    });
  return out;
}

/// Single characters the library teaches with more than one reading.
List<TwoSounds> twoSounds(Library lib) {
  final byHanzi = <String, List<Entry>>{};
  for (final e in lib.entries) {
    if (e.isSentence || e.simplified.runes.length != 1) continue;
    final list = byHanzi.putIfAbsent(e.simplified, () => []);
    if (!list.any((o) => o.pinyinNumbered.toLowerCase() == e.pinyinNumbered.toLowerCase())) list.add(e);
  }
  final out = [
    for (final MapEntry(:key, :value) in byHanzi.entries)
      if (value.length >= 2) TwoSounds(key, value..sort((a, b) => _rank(a).compareTo(_rank(b)))),
  ]..sort((a, b) {
      int best(TwoSounds t) => t.readings.map(_rank).reduce(min);
      final c = best(a).compareTo(best(b));
      return c != 0 ? c : a.hanzi.compareTo(b.hanzi);
    });
  return out;
}

/// The tone change rules found on library words, each with up to [perRule]
/// examples, easiest first. The rules come from the data build (tools/pinyin.py).
List<ToneRule> toneRules(Library lib, {int perRule = 8}) {
  final byNote = <String, List<Entry>>{};
  for (final e in lib.entries) {
    if (e.isSentence) continue;
    for (final n in e.soundNotes) {
      byNote.putIfAbsent(n, () => []).add(e);
    }
  }
  final out = [
    for (final MapEntry(:key, :value) in byNote.entries)
      ToneRule(key, (value..sort((a, b) => _rank(a).compareTo(_rank(b)))).take(perRule).toList()),
  ]..sort((a, b) => (byNote[b.note]!.length).compareTo(byNote[a.note]!.length));
  return out;
}

/// One "Hear it, pick the tone" question: the word played and the set it
/// belongs to, whose words are the choices.
class ToneQuestion {
  ToneQuestion(this.answer, this.set);
  final Entry answer;
  final ToneSet set;
}

/// [count] questions, from [only] if given, else from every tone set. Words
/// the learner has starred come up more often. No word twice in a row.
List<ToneQuestion> toneQuestions(Library lib, Random rnd,
    {int count = 10, ToneSet? only, Set<String> starred = const {}}) {
  final sets = only == null ? toneSets(lib) : [only];
  // A character taught with two readings could be heard either way, so it is never the one played.
  final twice = {for (final t in twoSounds(lib)) t.hanzi};
  final pool = [
    for (final s in sets)
      for (final e in s.words)
        if (!twice.contains(e.simplified)) (e, s),
  ];
  if (pool.isEmpty) return [];
  final weighted = [
    for (final p in pool) ...[p, if (starred.contains(p.$1.id)) p, if (starred.contains(p.$1.id)) p],
  ];
  final out = <ToneQuestion>[];
  while (out.length < count) {
    final (e, s) = weighted[rnd.nextInt(weighted.length)];
    if (out.isNotEmpty && out.last.answer.id == e.id && pool.length > 1) continue;
    out.add(ToneQuestion(e, s));
  }
  return out;
}
