import 'dart:convert';
import 'dart:math';

import '../models/entry.dart';
import '../ui/drill_screen.dart' show distractors, pinyinDistractors;
import 'daily.dart';
import 'library.dart';
import 'user_store.dart';

/// Data for the home-screen widgets that the app works out ahead of time,
/// since a widget can't read the library itself (see android/.../Widgets.kt).

/// The kinds of quick question, each with its own home-screen widget, and the
/// key its questions are saved under (see QuizBase in Widgets.kt).
enum QuizKind {
  meaning('quiz', 'WHAT DOES IT MEAN?'),
  which('quizWhich', 'WHICH ONE IS IT?'),
  pinyin('quizPinyin', 'PICK THE PINYIN'),
  opposite('quizOpposite', "WHAT'S THE OPPOSITE?");

  const QuizKind(this.key, this.title);
  final String key;
  final String title;

  /// How answers on this widget are logged (see methodLabels).
  String get method => this == meaning ? 'widget' : 'widget${name[0].toUpperCase()}${name.substring(1)}';
}

/// The words quick questions are about: starred words first; with fewer than
/// [minStarred], HSK 1 words fill in so a widget is never empty.
List<Entry> _quizPool(Library library, UserStore store, List<Entry> shown, Random rnd, int count, int minStarred) {
  var pool = [
    for (final id in store.starred)
      if (library.byId[id] case final e? when !e.isSentence) e,
  ];
  if (pool.length < minStarred) pool = [...pool, ...shown.where((e) => e.hsk == 1)];
  return (pool.toSet().toList()..shuffle(rnd)).take(count).toList();
}

/// Questions for one quick-question widget: a word (or its meaning) and four
/// answers to tap. Each says what to show before and after the pick, so the
/// widget only lays them out.
List<Map<String, Object>> quizQuestions(Library library, UserStore store, Random rnd,
    {QuizKind kind = QuizKind.meaning, int count = 40, int minStarred = 4}) {
  final shown = [for (final e in library.entries) if (!e.isSentence && store.shows(e)) e];
  Map<String, Object> q(Entry e, List<Entry> options, Map<String, Object> show) => {
        'id': e.id,
        'kind': kind.name,
        'method': kind.method,
        'title': kind.title,
        'right': options.indexOf(e),
        ...show,
      };
  if (kind == QuizKind.opposite) return _oppositeQuestions(library, rnd, count);
  return [
    for (final e in _quizPool(library, store, shown, rnd, count, minStarred))
      if ((kind == QuizKind.pinyin ? pinyinDistractors(e, shown, 3, rnd) : distractors(e, shown, 3, rnd))
          case final others when others.length == 3)
        () {
          final options = [e, ...others]..shuffle(rnd);
          return switch (kind) {
            QuizKind.meaning => q(e, options, {
                'big': e.simplified,
                'bigHanzi': true,
                'tones': toneDigits(e),
                'after': e.pinyin,
                'opts': [for (final o in options) o.gloss],
                'optsHanzi': false,
                'rightMsg': 'Right!',
                'wrongMsg': 'It means: ${e.gloss}',
              }),
            QuizKind.which => q(e, options, {
                'big': e.gloss,
                'bigHanzi': false,
                'tones': '',
                'after': '',
                'opts': [for (final o in options) o.simplified],
                'optsHanzi': true,
                'rightMsg': 'Right! ${e.simplified} ${e.pinyin}',
                'wrongMsg': "It's ${e.simplified} ${e.pinyin}",
              }),
            _ => q(e, options, {
                'big': e.simplified,
                'bigHanzi': true,
                'tones': toneDigits(e),
                'after': e.gloss,
                'opts': [for (final o in options) o.pinyin],
                'optsHanzi': false,
                'rightMsg': 'Right!',
                'wrongMsg': "It's ${e.pinyin}",
              }),
          };
        }(),
  ];
}

/// "What's the opposite of 大?": the other word of the pair and three words
/// from other pairs. Pairs are from the library's opposite links.
List<Map<String, Object>> _oppositeQuestions(Library library, Random rnd, int count) {
  final pairs = library.opposites;
  final words = {for (final p in pairs) ...[p.a, p.b]}.toList();
  final out = <Map<String, Object>>[];
  for (final p in [...pairs]..shuffle(rnd)) {
    if (out.length == count) break;
    final flip = rnd.nextBool();
    final (ask, askEn, answer, answerEn) = flip ? (p.b, p.bEnglish, p.a, p.aEnglish) : (p.a, p.aEnglish, p.b, p.bEnglish);
    final others = <Entry>[];
    for (final w in [...words]..shuffle(rnd)) {
      if (others.length == 3) break;
      if (w.simplified == ask.simplified || w.simplified == answer.simplified) continue;
      if (others.any((o) => o.simplified == w.simplified)) continue;
      others.add(w);
    }
    if (others.length < 3) continue;
    final options = [answer, ...others]..shuffle(rnd);
    out.add({
      'id': ask.id,
      'kind': QuizKind.opposite.name,
      'method': QuizKind.opposite.method,
      'title': QuizKind.opposite.title,
      'big': ask.simplified,
      'bigHanzi': true,
      'tones': toneDigits(ask),
      'after': '${ask.pinyin} · $askEn',
      'opts': [for (final o in options) o.simplified],
      'optsHanzi': true,
      'right': options.indexOf(answer),
      'rightMsg': 'Right! ${answer.simplified} ${answer.pinyin}, $answerEn',
      'wrongMsg': 'Opposite: ${answer.simplified} ${answer.pinyin}, $answerEn',
    });
  }
  return out;
}

/// A mix of every kind, taking turns, for the mixed widget.
List<Map<String, Object>> mixedQuestions(Library library, UserStore store, Random rnd, {int count = 40}) {
  final lists = [
    for (final k in QuizKind.values) quizQuestions(library, store, rnd, kind: k, count: count ~/ QuizKind.values.length + 1),
  ];
  final out = <Map<String, Object>>[];
  for (var i = 0; out.length < count && lists.any((l) => i < l.length); i++) {
    for (final l in lists) {
      if (i < l.length && out.length < count) out.add(l[i]);
    }
  }
  return out;
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
/// list of {"id", "ok", "at" (milliseconds since 1970), "ms", "method"}. Anything unreadable is skipped.
List<({String id, bool right, int at, int ms, String method})> widgetAnswers(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return [
      for (final o in jsonDecode(json) as List)
        if (o case {'id': final String id, 'ok': final bool ok, 'at': final int at})
          (
            id: id,
            right: ok,
            at: at,
            ms: o['ms'] is int ? o['ms'] as int : 0,
            method: o['method'] is String && (o['method'] as String).startsWith('widget') ? o['method'] as String : 'widget',
          ),
    ];
  } catch (_) {
    return const [];
  }
}
