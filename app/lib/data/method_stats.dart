import 'user_store.dart';

/// Plain names for each practice method, in the order the statistics show them.
const methodLabels = {
  'cards': 'Flashcards',
  'listen': 'Hear it, pick the word',
  'meaning': 'See it, pick the meaning',
  'reverse': 'See the meaning, pick the word',
  'pinyin': 'See it, pick the pinyin',
  'order': 'Put a scale in order',
  'opposite': 'Pick the opposite',
  'type': 'Type the pinyin',
  'widget': 'Widget: what does it mean?',
  'widgetWhich': 'Widget: which one is it?',
  'widgetPinyin': 'Widget: pick the pinyin',
  'widgetOpposite': 'Widget: what\'s the opposite?',
  'tones': 'Hear it, pick the tone',
};

/// How one practice method has gone.
class MethodStats {
  MethodStats(this.method);
  final String method;
  int answers = 0, right = 0;
  Duration time = Duration.zero;

  /// Flashcard answers on words practised this way since their last flashcard,
  /// and how many of those were remembered. For 'cards' itself: words practised
  /// only with flashcards in between.
  int tested = 0, remembered = 0;

  String get label => methodLabels[method] ?? method;
  double? get rightRate => answers == 0 ? null : right / answers;
  double? get rememberRate => tested == 0 ? null : remembered / tested;
}

/// The fewest later flashcard answers before a method's memory rate is shown.
const minTested = 10;

/// Each method's answers, share right and time since [since], and how well words
/// practised that way were remembered on their next flashcard (over all history,
/// so there is enough to compare).
///
/// The flashcard is the fair test: it asks for the word from memory, whatever
/// method was used to practise it. A method helps if words practised with it
/// are remembered more often on their next flashcard than words practised with
/// flashcards alone.
List<MethodStats> methodStats(List<Review> reviews, DateTime since) {
  final by = {for (final m in methodLabels.keys) m: MethodStats(m)};
  // Word id -> methods used on it since its last flashcard answer.
  final between = <String, Set<String>>{};
  for (final r in reviews) {
    final s = by.putIfAbsent(r.method, () => MethodStats(r.method));
    if (!r.at.isBefore(since)) {
      s.answers++;
      if (r.right) s.right++;
      s.time += r.spent;
    }
    final id = r.id;
    if (id == null) continue;
    if (r.method != 'cards') {
      (between[id] ??= {}).add(r.method);
      continue;
    }
    if (!r.isNew) {
      final used = between[id] ?? const {};
      for (final m in used.isEmpty ? const {'cards'} : used) {
        by[m]!.tested++;
        if (r.right) by[m]!.remembered++;
      }
    }
    between.remove(id);
  }
  return [for (final s in by.values) if (s.answers > 0 || s.tested > 0) s];
}

/// The method whose words were remembered best, once there is enough to say.
MethodStats? bestMethod(List<MethodStats> stats) {
  MethodStats? best;
  for (final s in stats) {
    if (s.tested < minTested) continue;
    if (best == null || s.rememberRate! > best.rememberRate!) best = s;
  }
  return best;
}

/// For each word answered, how many times in a row it has been answered right,
/// counting back from its latest answer, by any practice method. A wrong answer
/// sets it back to 0.
Map<String, int> rightInARow(List<Review> reviews) {
  final run = <String, int>{};
  for (final r in reviews) {
    final id = r.id;
    if (id == null) continue;
    run[id] = r.right ? (run[id] ?? 0) + 1 : 0;
  }
  return run;
}

/// Answers and right answers for one practice method in one day, week or month.
typedef WeekCount = ({int answers, int right});

/// How the Progress charts group answers over time.
enum Period {
  day('Day', 14, 'Last 14 days', '14 days ago', 'Today', 'today'),
  week('Week', 8, 'Last 8 weeks', '8 weeks ago', 'This week', 'this week'),
  month('Month', 6, 'Last 6 months', '6 months ago', 'This month', 'this month');

  const Period(this.label, this.count, this.span, this.startLabel, this.endLabel, this.current);
  final String label;

  /// How many bars or points a chart shows.
  final int count;
  final String span, startLabel, endLabel, current;

  static Period byName(String? name) => Period.values.asNameMap()[name] ?? Period.week;

  /// Which of the last [count] periods up to [today] (oldest 0) [at] falls in,
  /// or null. Days and months are calendar ones; a week is the 7 days ending
  /// on today's weekday.
  int? indexOf(DateTime at, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final d = DateTime(at.year, at.month, at.day);
    if (d.isAfter(t)) return null;
    final back = switch (this) {
      Period.day => (t.difference(d).inHours / 24).round(),
      Period.week => (t.difference(d).inHours / 24).round() ~/ 7,
      Period.month => (t.year * 12 + t.month) - (d.year * 12 + d.month),
    };
    return back >= count ? null : count - 1 - back;
  }

  /// The first day of each period, oldest first.
  List<DateTime> starts(DateTime today) => [
        for (var back = count - 1; back >= 0; back--)
          switch (this) {
            Period.day => DateTime(today.year, today.month, today.day - back),
            Period.week => DateTime(today.year, today.month, today.day - 7 * back - 6),
            Period.month => DateTime(today.year, today.month - back),
          },
      ];

  /// A short label under each bar.
  List<String> labels(DateTime today) => [
        for (final d in starts(today))
          switch (this) {
            Period.day => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
            Period.week => '${d.day}/${d.month}',
            Period.month => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1],
          },
      ];
}

/// The answers in each of the last periods, oldest first.
List<List<Review>> byPeriod(List<Review> reviews, DateTime today, {Period period = Period.week}) {
  final out = List.generate(period.count, (_) => <Review>[]);
  for (final r in reviews) {
    if (period.indexOf(r.at, today) case final i?) out[i].add(r);
  }
  return out;
}

/// The last periods, oldest first: answers and right answers per practice method.
List<Map<String, WeekCount>> methodWeeks(List<Review> reviews, DateTime today, {Period period = Period.week}) => [
      for (final week in byPeriod(reviews, today, period: period))
        () {
          final m = <String, WeekCount>{};
          for (final r in week) {
            final c = m[r.method] ?? (answers: 0, right: 0);
            m[r.method] = (answers: c.answers + 1, right: c.right + (r.right ? 1 : 0));
          }
          return m;
        }(),
    ];

/// Answers and right answers among [reviews] that pass [test].
WeekCount countOf(Iterable<Review> reviews, bool Function(Review) test) {
  var answers = 0, right = 0;
  for (final r in reviews) {
    if (!test(r)) continue;
    answers++;
    if (r.right) right++;
  }
  return (answers: answers, right: right);
}

/// Flashcards of words seen before: the test of memory.
bool isRecall(Review r) => r.method == 'cards' && !r.isNew;

/// Hearing the word and picking it.
bool isListening(Review r) => r.method == 'listen';

/// Seeing the word (or its meaning) and picking the answer.
bool isReading(Review r) =>
    const {'meaning', 'reverse', 'pinyin', 'widget', 'widgetWhich', 'widgetPinyin'}.contains(r.method);

/// Words missed at least [minMisses] times since [since], most missed first:
/// (word id, misses, answers).
List<(String, int, int)> trickyWords(List<Review> reviews, DateTime since, {int minMisses = 2, int limit = 10}) {
  final misses = <String, int>{}, answers = <String, int>{};
  for (final r in reviews) {
    final id = r.id;
    if (id == null || r.at.isBefore(since)) continue;
    answers[id] = (answers[id] ?? 0) + 1;
    if (!r.right) misses[id] = (misses[id] ?? 0) + 1;
  }
  final out = [
    for (final e in misses.entries)
      if (e.value >= minMisses) (e.key, e.value, answers[e.key]!),
  ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : (b.$2 / b.$3).compareTo(a.$2 / a.$3));
  return out.take(limit).toList();
}

/// The fewest answers in a day, week or month before its share right is drawn.
const minWeekAnswers = 3;
