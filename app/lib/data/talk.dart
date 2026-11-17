/// What happened in one conversation: kept so the review, the scene list's
/// marks and Progress can all be worked out from it.
library;

/// One of your turns in a conversation.
class TalkTurn {
  const TalkTurn({
    required this.line,
    required this.picked,
    this.wrongPicks = 0,
    this.tries = 0,
    this.saidWell = false,
    this.heardRight = 0,
    this.heardOf = 0,
    this.slips = const [],
    this.choice = true,
  });

  /// The line whose place your reply took (d2.2), and the reply you said (an entry id).
  final String line, picked;

  /// Wrong replies picked before the right one.
  final int wrongPicks;

  /// Times you held the mic, and whether the last of them was heard right.
  final int tries;
  final bool saidWell;

  /// Characters the recogniser heard right on your last try, out of how many.
  final int heardRight, heardOf;

  /// What was heard instead, as "忙>慢", from your last try.
  final List<String> slips;

  /// False for your opening line as the first speaker, which isn't a choice.
  final bool choice;

  bool get firstTime => wrongPicks == 0;
  bool get spoken => tries > 0;

  Map<String, Object> toJson() => {
        'l': line,
        'p': picked,
        if (wrongPicks > 0) 'w': wrongPicks,
        if (tries > 0) 't': tries,
        if (saidWell) 'ok': 1,
        if (heardOf > 0) 'h': [heardRight, heardOf],
        if (slips.isNotEmpty) 's': slips,
        if (!choice) 'c': 0,
      };

  factory TalkTurn.fromJson(Map j) {
    final h = j['h'] as List?;
    return TalkTurn(
      line: j['l'] as String,
      picked: j['p'] as String,
      wrongPicks: (j['w'] as num?)?.toInt() ?? 0,
      tries: (j['t'] as num?)?.toInt() ?? 0,
      saidWell: j['ok'] == 1,
      heardRight: h == null ? 0 : (h[0] as num).toInt(),
      heardOf: h == null ? 0 : (h[1] as num).toInt(),
      slips: List<String>.from(j['s'] as List? ?? const []),
      choice: j['c'] != 0,
    );
  }
}

/// How a scene went, for its mark on the list.
enum TalkMark { good, middling, poor }

/// One go at a scene, finished or stopped early.
class TalkRun {
  const TalkRun({
    required this.at,
    required this.scene,
    required this.seconds,
    required this.finished,
    required this.turns,
    this.youStart = false,
    this.chooseOnly = false,
    this.englishPeeks = 0,
  });

  /// When it ended.
  final DateTime at;
  final String scene;
  final int seconds;
  final bool finished, youStart, chooseOnly;
  final List<TalkTurn> turns;

  /// Times you tapped EN to see the English.
  final int englishPeeks;

  List<TalkTurn> get choices => [for (final t in turns) if (t.choice) t];
  int get firstTime => choices.where((t) => t.firstTime).length;
  List<TalkTurn> get spokenTurns => [for (final t in turns) if (t.spoken) t];
  int get saidWell => spokenTurns.where((t) => t.saidWell).length;
  int get tries => turns.fold(0, (a, t) => a + t.tries);

  /// Tries per reply said, or null when nothing was said.
  double? get triesPerReply => spokenTurns.isEmpty ? null : tries / spokenTurns.length;

  /// Share of characters heard right on your last try at each reply, or null.
  double? get heardShare {
    final of = turns.fold(0, (a, t) => a + t.heardOf);
    return of == 0 ? null : turns.fold(0, (a, t) => a + t.heardRight) / of;
  }

  /// Sound slips, most often first: "忙>慢" -> 2.
  Map<String, int> get slipCounts {
    final out = <String, int>{};
    for (final t in turns) {
      for (final s in t.slips) {
        out[s] = (out[s] ?? 0) + 1;
      }
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Green when you understood nearly every line (and said most of them well,
  /// if you spoke); red when you missed half or more; amber in between.
  TalkMark get mark {
    final n = choices.length;
    final understood = n == 0 ? 1.0 : firstTime / n;
    final spoke = spokenTurns.length;
    final said = spoke == 0 ? null : saidWell / spoke;
    if (understood < 0.5 || (said != null && said < 0.34)) return TalkMark.poor;
    if (understood >= 0.8 && (said == null || said >= 0.6)) return TalkMark.good;
    return TalkMark.middling;
  }

  Map<String, Object> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'scene': scene,
        'sec': seconds,
        if (!finished) 'stopped': 1,
        if (youStart) 'first': 1,
        if (chooseOnly) 'choose': 1,
        if (englishPeeks > 0) 'en': englishPeeks,
        'turns': [for (final t in turns) t.toJson()],
      };

  factory TalkRun.fromJson(Map j) => TalkRun(
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
        scene: j['scene'] as String,
        seconds: (j['sec'] as num?)?.toInt() ?? 0,
        finished: j['stopped'] != 1,
        youStart: j['first'] == 1,
        chooseOnly: j['choose'] == 1,
        englishPeeks: (j['en'] as num?)?.toInt() ?? 0,
        turns: [for (final t in j['turns'] as List) TalkTurn.fromJson(t as Map)],
      );

  /// The same go, from either device, for merging.
  String get key => '${at.millisecondsSinceEpoch}|$scene';
}

/// Every go at [scene], oldest first.
List<TalkRun> runsOf(List<TalkRun> runs, String scene) => [for (final r in runs) if (r.scene == scene) r];

/// When a scene comes back for review: a poor go after 2 days, a middling one
/// after 4, a good one after 10.
DateTime reviewDue(TalkRun last) =>
    last.at.add(Duration(days: switch (last.mark) { TalkMark.poor => 2, TalkMark.middling => 4, TalkMark.good => 10 }));
