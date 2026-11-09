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

/// Answers and right answers for one practice method in one week.
typedef WeekCount = ({int answers, int right});

/// The answers in each of the last [weeks] weeks, oldest first; the last week
/// ends with [today] and each one is 7 days.
List<List<Review>> byWeek(List<Review> reviews, DateTime today, {int weeks = 8}) {
  final out = List.generate(weeks, (_) => <Review>[]);
  final end = DateTime(today.year, today.month, today.day + 1);
  for (final r in reviews) {
    final w = weekOf(r.at, end, weeks);
    if (w != null) out[w].add(r);
  }
  return out;
}

/// Which of the [weeks] weeks before [end] (oldest 0) [at] falls in, or null.
int? weekOf(DateTime at, DateTime end, int weeks) {
  if (!at.isBefore(end)) return null;
  final back = end.difference(at).inHours ~/ (24 * 7);
  return back >= weeks ? null : weeks - 1 - back;
}

/// The last [weeks] weeks, oldest first: answers and right answers per practice method.
List<Map<String, WeekCount>> methodWeeks(List<Review> reviews, DateTime today, {int weeks = 8}) => [
      for (final week in byWeek(reviews, today, weeks: weeks))
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
bool isReading(Review r) => const {'meaning', 'reverse', 'pinyin'}.contains(r.method);

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

/// The fewest answers in a week before its share right is drawn.
const minWeekAnswers = 3;
