import 'dart:math';

import '../models/entry.dart';
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
