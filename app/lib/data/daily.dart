import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'library.dart';
import 'user_store.dart';

/// Midnight at the start of [t]'s day.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// The same word all day, a different one each day, from the words (not sentences).
Entry? wordOfTheDay(Library library, DateTime day) {
  final words = [for (final e in library.entries) if (!e.isSentence) e];
  if (words.isEmpty) return null;
  final days = dayOf(day).difference(DateTime(2024)).inDays;
  // A large prime step walks through the whole list before repeating.
  return words[(days * 7919) % words.length];
}

/// How many flashcards will be due by the end of each of the next [days] days,
/// if nothing is studied in between. Starred words have two cards each, and a
/// card never studied counts as due.
List<(DateTime, int)> dueByDay(UserStore store, DateTime now, {int days = 14}) {
  const sched = Scheduler();
  final cards = [
    for (final id in store.starred)
      for (final d in Direction.values) store.card(id, d),
  ];
  final today = dayOf(now);
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = today.add(Duration(days: i));
        final end = day.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        return (day, cards.where((c) => sched.isDue(c, end)).length);
      }(),
  ];
}

/// Tone digits for each character of [e.simplified] ('0' where a character has
/// no syllable, such as punctuation), for colouring characters outside Flutter.
String toneDigits(Entry e) {
  final out = StringBuffer();
  var i = 0;
  for (final ch in e.simplified.split('')) {
    if (i < e.syllables.length && e.syllables[i].hanzi == ch) {
      out.write(e.syllables[i].tone);
      i++;
    } else {
      out.write('0');
    }
  }
  return out.toString();
}
