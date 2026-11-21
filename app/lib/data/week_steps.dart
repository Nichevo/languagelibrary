import '../models/journey_week.dart';
import '../srs/scheduler.dart';
import 'adapt.dart';
import 'daily.dart';
import 'journey.dart';
import 'say_it.dart';
import 'user_store.dart';

/// The kinds of step a mixed week day is made of. [short] labels the step bar.
enum StepKind {
  meet('Meet', 'Meet each word'),
  meaning('Meaning', 'See it, pick the meaning'),
  listen('Hear', 'Hear it, pick the word'),
  recall('Pick', 'Pick the word or the pinyin'),
  mixed('Mixed', 'Mixed questions'),
  type('Type', 'Type the pinyin'),
  cards('Cards', 'Flashcards'),
  dueCards('Due', 'Flashcards that are due'),
  sayIt('Say it', 'Say it');

  const StepKind(this.short, this.title);
  final String short, title;
}

/// One step of a mixed week day: a short round over [ids].
class DayStep {
  const DayStep(this.kind, this.ids, {this.extra});
  final StepKind kind;
  final List<String> ids;

  /// Why the step was added to the usual day, for example "needs more",
  /// when last week's results added it (see data/adapt.dart).
  final String? extra;
}

/// The step kind for a practice type group (see `typeGroups`).
StepKind groupStep(String group) => switch (group) {
      'meaning' => StepKind.meaning,
      'listen' => StepKind.listen,
      'recall' => StepKind.recall,
      'type' => StepKind.type,
      _ => StepKind.sayIt,
    };

/// Multiple-choice question kinds, as logged (see `Choice` in drill_screen.dart).
const choiceMethods = ['listen', 'meaning', 'reverse', 'pinyin'];

/// How many words the Friday "Type the pinyin" step takes.
const typeStepWords = 8;

/// The steps of day [day] (0 = Monday) of [week], or null when that day isn't
/// a mixed one: the practice-type, Sentences and recap days stay as they are,
/// and so does every day when mixed practice is switched off.
///
/// Steps go from easy to hard: meet a word, recognise it, hear it, say it.
/// What a step picks depends only on answers given before today, so the steps
/// don't change part way through a day.
List<DayStep>? daySteps(UserStore store, JourneyWeek week, int day, DateTime now) {
  if (!store.weekMix) return null;
  final plan = dayPlan(week, day);
  if (plan.kind != DayKind.meet && plan.kind != DayKind.practise) return null;
  final w = week.words;
  if (w.isEmpty) return null;
  final half = (w.length + 1) ~/ 2;
  if (week.isReview) {
    return [DayStep(StepKind.mixed, w), DayStep(StepKind.dueCards, w)];
  }
  final a = week.adapt;
  int level(String g) => a?.typeLevel(g) ?? 0;
  // A type that's easy for the learner gets a shorter round: every other word.
  List<String> round(String g, List<String> ids) =>
      level(g) == 1 && ids.length > 3 ? [for (final (i, id) in ids.indexed) if (i.isEven) id] : ids;
  // Say it is hard work, so it never grows with the number of words.
  List<String> say(List<String> ids) => ids.take(hardCap).toList();
  return switch (day) {
    0 => [
      DayStep(StepKind.meet, plan.ids),
      DayStep(StepKind.meaning, round('meaning', plan.ids)),
      DayStep(StepKind.listen, round('listen', plan.ids)),
      DayStep(StepKind.sayIt, say(plan.ids)),
    ],
    1 => [
      DayStep(StepKind.meet, plan.ids),
      DayStep(StepKind.meaning, round('meaning', plan.ids)),
      // Monday's words come back to be heard again.
      DayStep(StepKind.listen, round('listen', [...plan.ids, ...w.sublist(0, half)])),
      DayStep(StepKind.sayIt, say(plan.ids)),
    ],
    2 => [
      DayStep(StepKind.cards, w),
      DayStep(StepKind.recall, round('recall', w)),
      ...extraSteps(store, week, now),
    ],
    _ => [
      DayStep(StepKind.mixed, w),
      DayStep(StepKind.type, mostMissed(store, week, now, level('type') == 1 ? hardCap ~/ 2 : typeStepWords)),
      DayStep(StepKind.dueCards, w),
    ],
  };
}

/// Wednesday's extra rounds from last week's results: a short round of the
/// most missed words for each type that needs more, then the type after one
/// that's easy. At most two, and at most one of them a hard practice.
List<DayStep> extraSteps(UserStore store, JourneyWeek week, DateTime now) {
  final a = week.adapt;
  if (a == null || a.types.isEmpty) return const [];
  final wanted = <(String, String)>[
    for (final g in typeGroups)
      if (a.typeLevel(g) == -1) (g, 'needs more'),
    for (final (i, g) in typeGroups.indexed)
      if (a.typeLevel(g) == 1 && i + 1 < typeGroups.length && a.typeLevel(typeGroups[i + 1]) != -1)
        (typeGroups[i + 1], 'new for you'),
  ];
  final words = mostMissed(store, week, now, extraWords);
  final out = <DayStep>[];
  var hard = false;
  for (final (g, why) in wanted) {
    // Wednesday already picks the word or the pinyin.
    if (out.length >= 2 || (g == 'recall' && why != 'needs more') || out.any((s) => s.kind == groupStep(g))) continue;
    final isHard = g == 'type' || g == 'speak';
    if (isHard && hard) continue;
    hard |= isHard;
    out.add(DayStep(groupStep(g), words, extra: why));
  }
  return out;
}

/// Answers on [week]'s words from the start of the week up to the start of
/// today, by word.
Map<String, List<Review>> _weekAnswers(UserStore store, JourneyWeek week, DateTime now) {
  final words = week.words.toSet();
  final today = dayOf(now);
  final out = <String, List<Review>>{};
  for (final r in store.reviews) {
    final id = r.id;
    if (id == null || !words.contains(id) || r.at.isBefore(week.start) || !r.at.isBefore(today)) continue;
    (out[id] ??= []).add(r);
  }
  return out;
}

/// Up to [count] of [week]'s words, the ones answered wrong most this week first
/// (in week order on a tie).
List<String> mostMissed(UserStore store, JourneyWeek week, DateTime now, int count) {
  final answers = _weekAnswers(store, week, now);
  int misses(String id) => (answers[id] ?? const []).where((r) => !r.right).length;
  final order = {for (final (i, id) in week.words.indexed) id: i};
  final ids = [...week.words]
    ..sort((a, b) {
      final m = misses(b).compareTo(misses(a));
      return m != 0 ? m : order[a]!.compareTo(order[b]!);
    });
  return ids.take(count).toList();
}

/// The question kind for each of [ids] in a mixed round: the kind answered
/// wrong most on that word this week; with none wrong, the kind used least on
/// it this week, so each word gets a different kind from last time. [canOrder]
/// says which words are on a scale, for "put it in order".
Map<String, String> mixedKinds(
  UserStore store,
  JourneyWeek week,
  List<String> ids,
  DateTime now, {
  bool Function(String id)? canOrder,
}) {
  final answers = _weekAnswers(store, week, now);
  final out = <String, String>{};
  for (final (i, id) in ids.indexed) {
    // Kinds that were easy last week only come up for words they tripped on.
    final easy = {
      for (final k in choiceMethods)
        if (week.adapt?.typeLevel(groupOf(k)!) == 1) k,
    };
    final all = [...choiceMethods, if (canOrder?.call(id) ?? false) 'order'];
    final missedEasy = (answers[id] ?? const <Review>[]).any((r) => easy.contains(r.method) && !r.right);
    final rest = [for (final k in all) if (!easy.contains(k)) k];
    final kinds = missedEasy || rest.isEmpty ? all : rest;
    final wrong = {for (final k in kinds) k: 0};
    final used = {for (final k in kinds) k: 0};
    for (final r in answers[id] ?? const <Review>[]) {
      if (!used.containsKey(r.method)) continue;
      used[r.method] = used[r.method]! + 1;
      if (!r.right) wrong[r.method] = wrong[r.method]! + 1;
    }
    // Start at a different kind for each word, so ties spread out.
    final turn = [for (var k = 0; k < kinds.length; k++) kinds[(i + k) % kinds.length]];
    var best = turn.first;
    for (final k in turn) {
      if (wrong[k]! > wrong[best]!) best = k;
    }
    if (wrong[best] == 0) {
      for (final k in turn) {
        if (used[k]! < used[best]!) best = k;
      }
    }
    out[id] = best;
  }
  return out;
}

/// What a step's done words are saved under today.
String stepKey(JourneyWeek week, int day, int step, DateTime now) => '${dayKey(now)}|${dayKey(week.start)}|$day|$step';

/// The words of [step] done today. Say it counts every word tried today.
Set<String> stepDone(UserStore store, JourneyWeek week, int day, int index, DayStep step, DateTime now) {
  final ids = step.ids.toSet();
  if (step.kind == StepKind.sayIt) {
    return {
      for (final id in sayItTriedToday(store, now).keys)
        if (ids.contains(id)) id,
    };
  }
  return {
    for (final id in store.weekSteps[stepKey(week, day, index, now)] ?? const <String>[])
      if (ids.contains(id)) id,
  };
}

/// Cards of [ids] due now.
int dueAmong(UserStore store, List<String> ids, DateTime now) {
  const sched = Scheduler();
  var n = 0;
  for (final id in ids) {
    for (final d in Direction.values) {
      if (sched.isDue(store.card(id, d), now)) n++;
    }
  }
  return n;
}

/// Whether [step] is finished for today. The due-cards step is finished when
/// nothing is due (which may be from the start).
bool stepComplete(UserStore store, JourneyWeek week, int day, int index, DayStep step, DateTime now) {
  if (step.kind == StepKind.dueCards) return dueAmong(store, step.ids, now) == 0;
  if (step.ids.isEmpty) return true;
  return stepDone(store, week, day, index, step, now).length >= step.ids.toSet().length;
}

/// The first step of [steps] not finished today, or null when the day is done.
int? nextStepIndex(UserStore store, JourneyWeek week, int day, List<DayStep> steps, DateTime now) {
  for (final (i, s) in steps.indexed) {
    if (!stepComplete(store, week, day, i, s, now)) return i;
  }
  return null;
}

/// How each practice type went on [week]'s words during the week, best first:
/// (method, right, answered). Only types answered at least [atLeast] times.
List<(String, int, int)> methodResults(UserStore store, JourneyWeek week, {int atLeast = 5}) {
  final words = week.words.toSet();
  final end = DateTime(week.start.year, week.start.month, week.start.day + 7);
  final right = <String, int>{}, total = <String, int>{};
  for (final r in store.reviews) {
    final id = r.id;
    if (id == null || !words.contains(id) || r.at.isBefore(week.start) || !r.at.isBefore(end)) continue;
    final m = r.method == 'opposite' ? 'order' : r.method;
    total[m] = (total[m] ?? 0) + 1;
    if (r.right) right[m] = (right[m] ?? 0) + 1;
  }
  for (final t in store.speakTries) {
    if (!words.contains(t.id) || t.at.isBefore(week.start) || !t.at.isBefore(end)) continue;
    total['speak'] = (total['speak'] ?? 0) + 1;
    if (t.right) right['speak'] = (right['speak'] ?? 0) + 1;
  }
  final out = [
    for (final MapEntry(key: m, value: n) in total.entries)
      if (n >= atLeast) (m, right[m] ?? 0, n),
  ];
  out.sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));
  return out;
}
