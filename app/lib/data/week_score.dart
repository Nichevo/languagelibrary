import '../models/journey_week.dart';
import 'adapt.dart';
import 'daily.dart';
import 'user_store.dart';

// The week's score and the check-back: the week's words are asked the same
// kind of question three times, when first met (answers the meet days already
// ask), in a short check on Sunday, and again five weeks later. Check answers
// are kept apart from the practice answers, so they don't move the week's
// "Right %", the adjusting rules or the practice statistics.

/// The most words a check asks, however many words the week has.
const checkWords = 20;

/// How long after the Sunday check the check-back comes.
const checkBackWeeks = 5;

/// The kinds of question a check asks, the ones the meet days ask.
const checkKinds = ['meaning', 'listen'];

DateTime _plus(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// When [week]'s Sunday check can be taken: from its Sunday until the end of
/// the week after, while its recap can still be opened.
(DateTime, DateTime) checkWindow(JourneyWeek week) => (_plus(week.start, 6), _plus(week.start, 14));

/// When [week]'s check-back can be taken: from the Sunday five weeks after its
/// Sunday, for a week.
(DateTime, DateTime) checkBackWindow(JourneyWeek week) {
  final from = _plus(week.start, 6 + 7 * checkBackWeeks);
  return (from, _plus(from, 7));
}

bool _within((DateTime, DateTime) w, DateTime now) => !now.isBefore(w.$1) && now.isBefore(w.$2);

/// [week]'s held words and their question kinds, with what each got when it
/// was first asked that kind of question in the week. The saved set once a
/// check has been taken; otherwise worked out from the week's answers.
///
/// Words take turns: meaning, then listen. A word never asked its turn's kind
/// but asked the other one takes the other one, so it can be compared.
HeldCheck heldFor(UserStore store, JourneyWeek week) {
  if (week.held case final h?) return h;
  final ids = week.words.take(checkWords).toList();
  final wanted = ids.toSet();
  final end = _plus(week.start, 6);
  // The first answer of each kind on each word, before the week's Sunday.
  final firstAt = <(String, String), DateTime>{};
  final firstRight = <(String, String), bool>{};
  for (final r in store.reviews) {
    final id = r.id;
    if (id == null || !wanted.contains(id) || !checkKinds.contains(r.method)) continue;
    if (r.at.isBefore(week.start) || !r.at.isBefore(end)) continue;
    final key = (id, r.method);
    if (firstAt[key] case final t? when !r.at.isBefore(t)) continue;
    firstAt[key] = r.at;
    firstRight[key] = r.right;
  }
  final kinds = <String, String>{};
  final first = <String, bool>{};
  for (final (i, id) in ids.indexed) {
    final turn = checkKinds[i % 2], other = checkKinds[(i + 1) % 2];
    final kind = firstRight.containsKey((id, turn)) || !firstRight.containsKey((id, other)) ? turn : other;
    kinds[id] = kind;
    if (firstRight[(id, kind)] case final right?) first[id] = right;
  }
  return HeldCheck(kinds: kinds, first: first);
}

/// Whether [week]'s Sunday check is open and not yet taken.
bool canCheck(JourneyWeek week, DateTime now) =>
    !week.isReview && week.words.isNotEmpty && week.held?.sunday == null && _within(checkWindow(week), now);

/// Whether [week]'s check-back is open and not yet taken. A week with no
/// Sunday check still gets one when its words were asked when first met.
bool canCheckBack(UserStore store, JourneyWeek week, DateTime now) {
  if (week.isReview || week.words.isEmpty || week.held?.back != null || !_within(checkBackWindow(week), now)) return false;
  final h = heldFor(store, week);
  return h.sunday != null || h.first.isNotEmpty;
}

/// The weeks whose check-back is open now, oldest first.
List<JourneyWeek> checkBacksDue(UserStore store, DateTime now) =>
    [for (final w in store.weeks) if (canCheckBack(store, w, now)) w];

/// Saves the answers of [week]'s Sunday check ([back] false) or check-back.
Future<void> saveCheck(UserStore store, JourneyWeek week, Map<String, bool> answers, DateTime now, {bool back = false}) {
  final h = heldFor(store, week);
  return store.setHeld(week.start, back ? h.copyWith(back: answers, backAt: now) : h.copyWith(sunday: answers, sundayAt: now));
}

/// Percent right of [m], or null when empty.
int? percentOf(Map<String, bool>? m) =>
    m == null || m.isEmpty ? null : (100 * m.values.where((r) => r).length / m.length).round();

/// The words of [m] answered wrong, in order.
List<String> wrongIn(Map<String, bool>? m) => [for (final MapEntry(:key, :value) in (m ?? const {}).entries) if (!value) key];

/// A week's three numbers, for the recap and Progress.
class WeekScore {
  WeekScore(this.week, this.held);
  final JourneyWeek week;
  final HeldCheck held;

  /// Percent right when first met, on the words that were asked then.
  int? get first => percentOf(held.first);

  /// Percent right at the Sunday check: the week's score.
  int? get sunday => percentOf(held.sunday);

  /// Percent right at the check-back.
  int? get back => percentOf(held.back);

  /// Words right when first met that were still right on Sunday, of those
  /// right when first met and checked on Sunday: (kept, of).
  (int, int) get keptToSunday => _kept(held.first, held.sunday);

  /// Words right on Sunday still right at the check-back (or, with no Sunday
  /// check, right when first met): (held, of).
  (int, int) get heldToBack => _kept(held.sunday ?? held.first, held.back);

  static (int, int) _kept(Map<String, bool>? before, Map<String, bool>? after) {
    if (before == null || after == null) return (0, 0);
    var kept = 0, of = 0;
    for (final MapEntry(:key, :value) in before.entries) {
      if (!value || !after.containsKey(key)) continue;
      of++;
      if (after[key]!) kept++;
    }
    return (kept, of);
  }
}

/// Every week with a score of any kind, oldest first.
List<WeekScore> weekScores(UserStore store) => [
      for (final w in store.weeks)
        if (w.held case final h? when h.sunday != null || h.back != null) WeekScore(w, h),
    ];

/// Words answered wrong at a check-back taken in the [days] days before
/// today, newest check-back first, and not since answered right twice in
/// practice: the ones that cycle back in. Only check-backs from before today
/// count, so a day's steps don't change part way through it.
List<String> cycleBackWords(UserStore store, DateTime now, {int days = 14, int? count = extraWords}) {
  final today = dayOf(now);
  final since = today.subtract(Duration(days: days));
  final backs = [
    for (final w in store.weeks)
      if (w.held case HeldCheck(back: final b?, backAt: final at?) when !at.isBefore(since) && at.isBefore(today)) (at, b),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  final out = <String>[];
  for (final (at, answers) in backs) {
    for (final id in wrongIn(answers)) {
      if (out.contains(id)) continue;
      final rightSince = store.reviews.where((r) => r.id == id && r.method != 'cards' && r.right && r.at.isAfter(at)).length;
      if (rightSince < 2) out.add(id);
    }
  }
  return count == null ? out : out.take(count).toList();
}
