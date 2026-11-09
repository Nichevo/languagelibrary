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
