import '../srs/scheduler.dart';
import 'daily.dart';
import 'user_store.dart';

/// Answers of any kind given on [day].
int answersOn(List<Review> reviews, DateTime day) {
  final d = dayOf(day);
  return reviews.where((r) => dayOf(r.at) == d).length;
}

/// Days in a row, up to today, on which the daily goal was met. Today only
/// counts once it is met, so a streak isn't lost before the day is over.
int streak(List<Review> reviews, int goal, DateTime now) {
  final perDay = <DateTime, int>{};
  for (final r in reviews) {
    final d = dayOf(r.at);
    perDay[d] = (perDay[d] ?? 0) + 1;
  }
  var day = dayOf(now);
  if ((perDay[day] ?? 0) < goal) day = day.subtract(const Duration(days: 1));
  var n = 0;
  while ((perDay[day] ?? 0) >= goal) {
    n++;
    // Calendar days, so a change to or from daylight saving doesn't skip one.
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}

/// Answers on each of the last [days] days, oldest first, ending today.
List<(DateTime, int)> lastDays(List<Review> reviews, DateTime now, {int days = 7}) {
  final today = dayOf(now);
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (d, answersOn(reviews, d));
      }(),
  ];
}

/// The practice types the Today card can suggest, as logged in the practice log
/// ('order' stands for Pairs & scales, which also logs 'opposite').
const todayTypes = ['build', 'tones', 'order'];

/// What the Today card suggests next.
sealed class TodayStep {}

/// Flashcards that are due.
class DueCards extends TodayStep {
  DueCards(this.count);
  final int count;
}

/// A practice type used least in the last week.
class TryType extends TodayStep {
  TryType(this.method, this.lastWeek);
  final String method;
  final int lastWeek;
}

/// Due flashcards first; with none due, the practice type answered least in
/// the last 7 days (the first in [todayTypes] on a tie).
TodayStep nextStep(UserStore store, DateTime now) {
  const sched = Scheduler();
  final due = store.cards.values.where((c) => sched.isDue(c, now)).length;
  if (due > 0) return DueCards(due);
  final since = now.subtract(const Duration(days: 7));
  final counts = {for (final m in todayTypes) m: 0};
  for (final r in store.reviews) {
    final m = r.method == 'opposite' ? 'order' : r.method;
    if (!r.at.isBefore(since) && counts.containsKey(m)) counts[m] = counts[m]! + 1;
  }
  var best = todayTypes.first;
  for (final m in todayTypes) {
    if (counts[m]! < counts[best]!) best = m;
  }
  return TryType(best, counts[best]!);
}
