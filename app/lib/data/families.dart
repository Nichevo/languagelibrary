import '../models/entry.dart';
import 'library.dart';
import 'user_store.dart';

/// Every word and sentence in the library that uses one character, so one
/// character you know leads to many more: 在 → 现在, 在家, 我在喝牛奶。
class Family {
  Family(this.hanzi, this.heads, this.words, this.sentences);

  final String hanzi;

  /// The character as a word on its own (two when it has two readings).
  final List<Entry> heads;

  /// Other words with the character, easiest first.
  final List<Entry> words;
  final List<Entry> sentences;

  int get size => words.length + sentences.length;
  Iterable<Entry> get all => [...words, ...sentences];
}

/// The fewest other words and sentences a character needs to get a family.
const minFamily = 8;

/// Ids of entries with at least one card the learner knows (back in a week or more).
Set<String> knownIds(UserStore store) => {for (final k in store.firstKnown.keys) k.split(':').first};

/// Families for the characters the library has as words on their own, biggest
/// first. Only entries switched on in Settings ([shows]) count.
List<Family> families(Library lib, bool Function(Entry) shows, {int min = minFamily}) {
  final heads = <String, List<Entry>>{};
  final words = <String, List<Entry>>{};
  final sentences = <String, List<Entry>>{};
  for (final e in lib.entries) {
    if (!shows(e)) continue;
    final chars = e.simplified.runes.map(String.fromCharCode).toSet();
    if (!e.isSentence && e.simplified.runes.length == 1) {
      heads.putIfAbsent(e.simplified, () => []).add(e);
      continue;
    }
    for (final c in chars) {
      (e.isSentence ? sentences : words).putIfAbsent(c, () => []).add(e);
    }
  }
  final out = [
    for (final MapEntry(key: c, value: h) in heads.entries)
      if ((words[c]?.length ?? 0) + (sentences[c]?.length ?? 0) >= min)
        Family(c, h, words[c] ?? const [], sentences[c] ?? const []),
  ]..sort((a, b) {
      final s = b.size.compareTo(a.size);
      return s != 0 ? s : a.hanzi.compareTo(b.hanzi);
    });
  return out;
}

/// The family for [hanzi], if it has one.
Family? familyOf(Library lib, bool Function(Entry) shows, String hanzi) {
  for (final f in families(lib, shows)) {
    if (f.hanzi == hanzi) return f;
  }
  return null;
}

/// What to learn next in a family, and how many of its words are already known.
class NextStep {
  NextStep(this.entry, this.known, this.of);
  final Entry entry;
  final int known, of;
}

/// The sentence in [f] whose words the learner knows or has starred most of,
/// that they haven't started on yet. Without such a sentence, the easiest word
/// not yet started. Null when everything in the family has been started.
NextStep? nextToLearn(Library lib, Family f, UserStore store) {
  final known = knownIds(store);
  bool started(Entry e) => known.contains(e.id) || store.isStarred(e.id);
  NextStep? best;
  for (final s in f.sentences) {
    if (started(s)) continue;
    final parts = [
      for (final r in s.related)
        if (lib.byId[r.id] case final w? when !w.isSentence) w,
    ];
    if (parts.isEmpty) continue;
    final k = parts.where(started).length;
    if (k == 0) continue;
    final better = best == null ||
        k / parts.length > best.known / best.of ||
        (k / parts.length == best.known / best.of && s.simplified.length < best.entry.simplified.length);
    if (better) best = NextStep(s, k, parts.length);
  }
  if (best != null) return best;
  for (final w in f.words) {
    if (!started(w)) return NextStep(w, 0, 0);
  }
  return null;
}
