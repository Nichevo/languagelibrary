// Spaced repetition: decides when a flashcard comes back.
//
// A simplified version of the well-known SM-2 method: each card has an
// "ease" that goes down when you struggle and up when it is easy, and the
// gap before the next review grows by that ease each time you get it right.

enum Rating { again, hard, good, easy }

enum Direction {
  /// See Chinese (hanzi, pinyin or audio), recall the English.
  zhToEn,

  /// See the English, recall the Chinese.
  enToZh,
}

class CardState {
  const CardState({
    required this.reps,
    required this.intervalDays,
    required this.ease,
    required this.due,
    this.lapses = 0,
  });

  /// Correct answers in a row.
  final int reps;
  final double intervalDays;
  final double ease;
  final DateTime due;
  final int lapses;

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'interval': intervalDays,
        'ease': ease,
        'due': due.toIso8601String(),
        'lapses': lapses,
      };

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        reps: j['reps'] as int,
        intervalDays: (j['interval'] as num).toDouble(),
        ease: (j['ease'] as num).toDouble(),
        due: DateTime.parse(j['due'] as String),
        lapses: (j['lapses'] as int?) ?? 0,
      );
}

class Scheduler {
  const Scheduler();

  static const startEase = 2.5;
  static const minEase = 1.3;
  static const againDelay = Duration(minutes: 1);

  CardState review(CardState? card, Rating rating, DateTime now) {
    final reps = card?.reps ?? 0;
    final interval = card?.intervalDays ?? 0;
    var ease = card?.ease ?? startEase;
    final lapses = card?.lapses ?? 0;

    switch (rating) {
      case Rating.again:
        ease = (ease - 0.2).clamp(minEase, 5.0);
        return CardState(reps: 0, intervalDays: 0, ease: ease, due: now.add(againDelay), lapses: lapses + 1);
      case Rating.hard:
        ease = (ease - 0.15).clamp(minEase, 5.0);
        final next = reps == 0 ? 1.0 : (interval * 1.2).clamp(1.0, double.infinity);
        return _after(reps + 1, next, ease, now, lapses);
      case Rating.good:
        final next = switch (reps) { 0 => 1.0, 1 => 3.0, _ => interval * ease };
        return _after(reps + 1, next, ease, now, lapses);
      case Rating.easy:
        final next = switch (reps) { 0 => 3.0, 1 => 6.0, _ => interval * ease * 1.3 };
        ease = (ease + 0.15).clamp(minEase, 5.0);
        return _after(reps + 1, next, ease, now, lapses);
    }
  }

  CardState _after(int reps, double days, double ease, DateTime now, int lapses) {
    final rounded = days.roundToDouble().clamp(1.0, 3650.0);
    // Calendar days, so a change to or from daylight saving doesn't move it by an hour.
    final due = DateTime(now.year, now.month, now.day + rounded.toInt());
    return CardState(reps: reps, intervalDays: rounded, ease: ease, due: due, lapses: lapses);
  }

  /// Text for the button, e.g. "1 min", "1 day", "3 days".
  String preview(CardState? card, Rating rating, DateTime now) {
    if (rating == Rating.again) return '1 min';
    final days = review(card, rating, now).intervalDays.toInt();
    if (days < 31) return days == 1 ? '1 day' : '$days days';
    final months = (days / 30).round();
    return months == 1 ? '1 month' : '$months months';
  }

  bool isDue(CardState? card, DateTime now) => card == null || !card.due.isAfter(now);
}
