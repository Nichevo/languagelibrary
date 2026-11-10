import 'dart:convert';
import 'dart:math';

import '../ui/drill_screen.dart' show distractors;
import 'daily.dart';
import 'library.dart';
import 'user_store.dart';

/// Data for the home-screen widgets that the app works out ahead of time,
/// since a widget can't read the library itself (see android/.../Widgets.kt).

/// Questions for the quick-question widget: "What does 贵 mean?" with four
/// meanings to pick from. Starred words first; with fewer than [minStarred],
/// HSK 1 words fill in so the widget is never empty.
List<Map<String, Object>> quizQuestions(Library library, UserStore store, Random rnd,
    {int count = 40, int minStarred = 4}) {
  final shown = [for (final e in library.entries) if (!e.isSentence && store.shows(e)) e];
  var pool = [
    for (final id in store.starred)
      if (library.byId[id] case final e? when !e.isSentence) e,
  ];
  if (pool.length < minStarred) pool = [...pool, ...shown.where((e) => e.hsk == 1)];
  pool = (pool.toSet().toList()..shuffle(rnd)).take(count).toList();
  return [
    for (final e in pool)
      if (distractors(e, shown, 3, rnd) case final others when others.length == 3)
        () {
          final options = [e, ...others]..shuffle(rnd);
          return <String, Object>{
            'id': e.id,
            'hz': e.simplified,
            'tones': toneDigits(e),
            'py': e.pinyin,
            'en': e.gloss,
            'opts': [for (final o in options) o.gloss],
            'right': options.indexOf(e),
          };
        }(),
  ];
}

/// The scale shown on [day]: the scales take turns, one a day.
int scaleIndexFor(Library library, DateTime day) =>
    library.scales.isEmpty ? -1 : dayOf(day).difference(DateTime(2024)).inDays % library.scales.length;

/// A month of scale-of-the-day entries for the widget, from [today].
List<Map<String, Object>> scaleDays(Library library, DateTime today, {int days = 31}) => [
      for (var i = 0; i < days && library.scales.isNotEmpty; i++)
        () {
          final day = dayOf(today).add(Duration(days: i));
          final n = scaleIndexFor(library, day);
          final s = library.scales[n];
          return <String, Object>{
            'd': dayKey(day),
            'i': n,
            'name': s.name,
            'ends': '${s.from} → ${s.to}',
            'words': [
              for (final w in s.items) {'hz': w.entry.simplified, 'py': w.entry.pinyin, 'en': w.short},
            ],
          };
        }(),
    ];

/// The answers the quiz widget logged (see QuizWidget in Widgets.kt): a JSON
/// list of {"id", "ok", "at" (milliseconds since 1970), "ms"}. Anything unreadable is skipped.
List<({String id, bool right, int at, int ms})> widgetAnswers(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return [
      for (final o in jsonDecode(json) as List)
        if (o case {'id': final String id, 'ok': final bool ok, 'at': final int at})
          (id: id, right: ok, at: at, ms: o['ms'] is int ? o['ms'] as int : 0),
    ];
  } catch (_) {
    return const [];
  }
}
