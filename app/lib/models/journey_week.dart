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
    this.adapt,
    this.feel,
    this.keepNext = false,
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

  /// How the week was adjusted to how the week before went: its new-word
  /// count and a level for each practice type (see data/adapt.dart). Null
  /// for weeks planned before adjusting existed, or with it switched off.
  final WeekAdapt? adapt;

  /// How the learner said the week felt, from its recap: 'much' (too much),
  /// 'right' or 'little' (too little). Null when not asked or not answered.
  String? feel;

  /// The learner chose to keep this week's settings for next week instead of
  /// the suggested changes.
  bool keepNext;

  bool get isReview => path == 'review';

  JourneyWeek copyWith({DateTime? start, int? level, String? Function()? levelNote, WeekAdapt? Function()? adapt, List<String>? words}) => JourneyWeek(
        start: start ?? this.start,
        path: path,
        title: title,
        why: why,
        words: List.of(words ?? this.words),
        skill: skill,
        seed: seed,
        topic: topic,
        char: char,
        pattern: pattern,
        level: level ?? this.level,
        levelNote: levelNote != null ? levelNote() : this.levelNote,
        adapt: adapt != null ? adapt() : this.adapt,
        feel: feel,
        keepNext: keepNext,
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
        'adapt': ?adapt?.toJson(),
        'feel': ?feel,
        if (keepNext) 'keepNext': true,
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
      adapt: j['adapt'] == null ? null : WeekAdapt.fromJson(j['adapt'] as Map<String, dynamic>),
      feel: j['feel'] as String?,
      keepNext: j['keepNext'] as bool? ?? false,
    );
  }
}

/// How a week was adjusted from the week before it (see data/adapt.dart).
class WeekAdapt {
  const WeekAdapt({
    required this.pace,
    this.step = 0,
    this.goodRun = 0,
    this.types = const {},
    this.notes = const [],
  });

  /// New words planned for the week.
  final int pace;

  /// How [pace] moved from the week before: -1 down, 0 the same, 1 up.
  final int step;

  /// Weeks in a row, up to the one before this, that went well enough to
  /// add words.
  final int goodRun;

  /// A level for each practice type group ('meaning', 'listen', 'recall',
  /// 'type', 'speak'): -1 needs more, 0 working on it, 1 easy. Missing is 0.
  final Map<String, int> types;

  /// Why things changed, one short sentence each, for the week card and recap.
  final List<String> notes;

  int typeLevel(String group) => types[group] ?? 0;

  Map<String, dynamic> toJson() => {
        'pace': pace,
        if (step != 0) 'step': step,
        if (goodRun != 0) 'goodRun': goodRun,
        if (types.isNotEmpty) 'types': types,
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory WeekAdapt.fromJson(Map<String, dynamic> j) => WeekAdapt(
        pace: (j['pace'] as num).toInt(),
        step: (j['step'] as num?)?.toInt() ?? 0,
        goodRun: (j['goodRun'] as num?)?.toInt() ?? 0,
        types: {for (final MapEntry(:key, :value) in (j['types'] as Map? ?? const {}).entries) key as String: (value as num).toInt()},
        notes: List<String>.from(j['notes'] as List? ?? const []),
      );
}
