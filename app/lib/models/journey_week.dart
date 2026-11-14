/// One planned week of the learning journey: a theme, its words and the
/// practice type to lean on. Built by `planWeek` in data/journey.dart.
class JourneyWeek {
  JourneyWeek({
    required this.start,
    required this.path,
    required this.title,
    required this.why,
    required this.words,
    required this.skill,
    this.seed,
    this.topic,
    this.char,
    this.pattern,
    this.level = 0,
    this.levelNote,
  });

  /// Midnight on the Monday the week starts.
  final DateTime start;

  /// How the week was chosen: 'connections', 'topics', 'characters',
  /// 'sentences', 'hsk' or 'review'.
  final String path;

  /// For example "Grows from 饭" or "Food".
  final String title;

  /// One line on why these words, for example "Words that link to 饭".
  final String why;

  /// Entry ids, in the order they are met. Mutable so a word can be added.
  final List<String> words;

  /// The practice type to lean on (see `todayTypes`).
  final String skill;

  /// The word the week grows from, the topic, the character family and the
  /// sentence pattern, where the week has one.
  final String? seed, topic, char, pattern;

  /// How hard the Sentences day is, from -2 (shortest sentences, fewer of
  /// them) to 2 (longer ones, more of them). Set from how the previous week's
  /// sentences went (see `sentenceLevel` in data/journey.dart).
  final int level;

  /// Why the level changed, for example "Last week the recogniser understood
  /// 3 of 12 sentences, so these are shorter". Null when nothing changed.
  final String? levelNote;

  bool get isReview => path == 'review';

  JourneyWeek copyWith({DateTime? start, int? level, String? Function()? levelNote}) => JourneyWeek(
        start: start ?? this.start,
        path: path,
        title: title,
        why: why,
        words: List.of(words),
        skill: skill,
        seed: seed,
        topic: topic,
        char: char,
        pattern: pattern,
        level: level ?? this.level,
        levelNote: levelNote != null ? levelNote() : this.levelNote,
      );

  Map<String, dynamic> toJson() => {
        'start': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        'path': path,
        'title': title,
        'why': why,
        'words': words,
        'skill': skill,
        'seed': ?seed,
        'topic': ?topic,
        'char': ?char,
        'pattern': ?pattern,
        if (level != 0) 'level': level,
        'levelNote': ?levelNote,
      };

  factory JourneyWeek.fromJson(Map<String, dynamic> j) {
    final d = (j['start'] as String).split('-').map(int.parse).toList();
    return JourneyWeek(
      start: DateTime(d[0], d[1], d[2]),
      path: j['path'] as String,
      title: j['title'] as String,
      why: j['why'] as String? ?? '',
      words: List<String>.from(j['words'] as List),
      skill: j['skill'] as String? ?? 'cards',
      seed: j['seed'] as String?,
      topic: j['topic'] as String?,
      char: j['char'] as String?,
      pattern: j['pattern'] as String?,
      level: (j['level'] as num?)?.toInt() ?? 0,
      levelNote: j['levelNote'] as String?,
    );
  }
}
