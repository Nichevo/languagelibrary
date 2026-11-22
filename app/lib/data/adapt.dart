import 'dart:math';

import '../models/journey_week.dart';
import '../srs/scheduler.dart';
import 'daily.dart';
import 'user_store.dart';
import 'week_steps.dart';

// Weeks that adapt: each week's new-word count and the mix of practice types
// move a small step from how the week before went. Only one thing gets harder
// in a week, and the hard practices (type, build, say) never grow with the
// number of words: they are capped at [hardCap] words a day.

/// The practice types of a week day, easiest first. Each one, once easy,
/// makes room for the next.
const typeGroups = ['meaning', 'listen', 'recall', 'type', 'speak'];

const groupLabels = {
  'meaning': 'See it, pick the meaning',
  'listen': 'Hear it, pick the word',
  'recall': 'Pick the word or the pinyin',
  'type': 'Type the pinyin',
  'speak': 'Say it',
};

/// The week-day group a logged practice method belongs to, if any.
String? groupOf(String method) => switch (method) {
      'meaning' => 'meaning',
      'listen' => 'listen',
      'reverse' || 'pinyin' => 'recall',
      'type' => 'type',
      'speak' => 'speak',
      _ => null,
    };

/// How hard a practice method is: 0 you see the word and pick, 1 middle,
/// 2 you make the answer yourself.
int tierOf(String method) => switch (method) {
      'meaning' || 'opposite' || 'widget' || 'widgetWhich' || 'widgetPinyin' || 'widgetOpposite' => 0,
      'type' || 'build' || 'speak' || 'talk' => 2,
      _ => 1,
    };

/// The most words a day for each hard practice (type, say it), whatever the
/// number of new words.
const hardCap = 8;

/// Words in an extra round for a type that needs more, or one making room.
const extraWords = 6;

/// Answers a type needs in a week before its level can move.
const typeAnswersNeeded = 8;

/// Answers on the easier practices a week needs before the word count moves.
const answersNeeded = 20;

/// (easy at or above, needs more below), in percent right.
(int, int) typeThresholds(String group) => group == 'type' || group == 'speak' ? (75, 50) : (90, 60);

/// How a week went, as the adjusting rules see it.
class WeekCheck {
  WeekCheck({
    required this.right,
    required this.answers,
    required this.days,
    required this.due,
    required this.olderRight,
    required this.olderAnswered,
    required this.groups,
  });

  /// Right answers and all answers on the easier and middle practices the app
  /// checks (flashcards, marked by the learner, are left out).
  final int right, answers;

  /// Days with any practice on the week's words.
  final int days;

  /// Cards of the week's words due when the next week starts.
  final int due;

  /// The week before's words that came back during the week: how many were
  /// right the last time they were answered, of how many were answered.
  final int olderRight, olderAnswered;

  /// Per type group: (right, answers).
  final Map<String, (int, int)> groups;

  int get percent => answers == 0 ? 0 : (100 * right / answers).round();
  int get olderPercent => olderAnswered == 0 ? 0 : (100 * olderRight / olderAnswered).round();
  bool get olderCounts => olderAnswered >= 5;
}

/// How [week] went, looked at from [next] (the start of the week after).
WeekCheck checkWeek(UserStore store, JourneyWeek week, DateTime next) {
  final end = DateTime(week.start.year, week.start.month, week.start.day + 7);
  final to = next.isBefore(end) ? next : end;
  final words = week.words.toSet();
  var right = 0, answers = 0;
  final groups = <String, (int, int)>{};
  for (final (m, r, n) in methodResults(store, week, atLeast: 1)) {
    if (tierOf(m) < 2) {
      right += r;
      answers += n;
    }
    if (groupOf(m) case final g?) {
      final (gr, gn) = groups[g] ?? (0, 0);
      groups[g] = (gr + r, gn + n);
    }
  }
  final days = <int>{};
  for (final r in store.reviews) {
    if (r.id != null && words.contains(r.id) && !r.at.isBefore(week.start) && r.at.isBefore(to)) days.add(dayNumber(r.at));
  }
  for (final t in store.speakTries) {
    if (words.contains(t.id) && !t.at.isBefore(week.start) && t.at.isBefore(to)) days.add(dayNumber(t.at));
  }
  // The week before's words: right the last time they came back this week?
  final before = store.weeks.where((w) => w.start.isBefore(week.start) && !w.isReview).lastOrNull;
  final older = {...?before?.words}..removeAll(words);
  final last = <String, bool>{};
  for (final r in store.reviews) {
    final id = r.id;
    if (id == null || !older.contains(id) || r.at.isBefore(week.start) || !r.at.isBefore(to)) continue;
    last[id] = r.right;
  }
  return WeekCheck(
    right: right,
    answers: answers,
    days: days.length,
    due: _dueStarted(store, week.words, next),
    olderRight: last.values.where((v) => v).length,
    olderAnswered: last.length,
    groups: groups,
  );
}

/// The adjustments for the week starting [start], from the week before it,
/// or null when adjusting is switched off.
WeekAdapt? adaptFor(UserStore store, DateTime start) {
  if (!store.adaptOn) return null;
  final prev = store.weeks.where((w) => w.start.isBefore(start)).lastOrNull;
  final reset = store.paceSetAt != null && (prev == null || store.paceSetAt!.isAfter(prev.start));
  final was = reset ? null : prev?.adapt;
  final base = (was?.pace ?? store.journeyPace).clamp(store.paceMin, store.paceMax);
  final types = {...?was?.types};
  if (prev == null) return WeekAdapt(pace: base);
  if (prev.keepNext && was != null) {
    return WeekAdapt(pace: was.pace, goodRun: was.goodRun, types: types, notes: const ['You kept last week\'s settings']);
  }
  if (prev.isReview) {
    return WeekAdapt(pace: base, goodRun: was?.goodRun ?? 0, types: types, notes: const ['Last week was a review week, so nothing changed']);
  }

  final c = checkWeek(store, prev, start);
  final notes = <String>[];

  // What the numbers say about the number of new words.
  var numbers = 0;
  final why = <String>[];
  if (c.answers >= answersNeeded && c.percent < 65) {
    numbers = -1;
    why.add('${c.percent}% right last week');
  }
  if (c.due >= 20) {
    numbers = -1;
    why.add('${c.due} cards still due');
  }
  if (c.olderCounts && c.olderPercent < 60) {
    numbers = -1;
    why.add('only ${c.olderRight} of ${c.olderAnswered} words from the week before were remembered');
  }
  if (numbers == 0 &&
      c.answers >= answersNeeded &&
      c.percent >= 85 &&
      c.days >= 5 &&
      c.due < 15 &&
      (!c.olderCounts || c.olderPercent >= 80)) {
    numbers = 1;
    why.add('${c.percent}% right over ${c.days} days');
    if (c.olderCounts) why.add('${c.olderRight} of ${c.olderAnswered} words from the week before remembered');
  }

  // The learner's feeling moves it further, less far, or the other way.
  final feel = store.askFeel ? prev.feel : null;
  var dir = numbers;
  var share = 0.15;
  switch (feel) {
    case 'much':
      dir = -1;
      share = numbers == -1 ? 0.30 : 0.15;
      why.insert(0, 'you said last week was too much');
    case 'little':
      if (numbers == 1) {
        share = 0.30;
      } else if (numbers == 0) {
        dir = 1;
      }
      if (numbers != -1) why.insert(0, 'you said last week was too little');
    case 'right':
      share = 0.10;
  }

  // Going up: above 20 words, or soon after a step down, it takes two good
  // weeks in a row for each step up.
  var goodRun = dir == 1 ? (was?.goodRun ?? 0) + 1 : 0;
  final recent = store.weeks.where((w) => w.start.isBefore(start)).toList();
  final recentDown = recent.reversed.take(3).any((w) => w.adapt?.step == -1);
  final needRun = base >= 20 || recentDown ? 2 : 1;
  var held = false;
  if (dir == 1 && goodRun < needRun) {
    dir = 0;
    held = true;
  }
  var step = max(1, (base * share).round());
  if (dir == 1 && base >= 20) step = min(step, 2);
  final pace = (base + dir * step).clamp(store.paceMin, store.paceMax);
  final moved = pace.compareTo(base);
  if (moved == 1 && needRun == 2) goodRun = 0;
  final reason = why.isEmpty ? '' : ': ${why.join(', ')}';
  if (moved > 0) {
    notes.add('$pace new words, ${pace - base} more than last week$reason');
  } else if (moved < 0) {
    notes.add('$pace new words, ${base - pace} fewer than last week$reason');
  } else if (held) {
    notes.add('$pace new words again: one more good week and it goes up');
  } else if (dir != 0) {
    notes.add('$pace new words, as far as your limit goes');
  }

  // Each practice type: easy, working on it or needs more, one step at a time.
  for (final g in typeGroups) {
    final (r, n) = c.groups[g] ?? (0, 0);
    if (n < typeAnswersNeeded) continue;
    final pc = (100 * r / n).round();
    final (easy, needs) = typeThresholds(g);
    final target = pc >= easy ? 1 : (pc < needs ? -1 : 0);
    final old = types[g] ?? 0;
    var level = target.clamp(old - 1, old + 1);
    // Only one thing gets harder in a week.
    if (level > old && moved > 0) level = old;
    if (level == old) continue;
    level == 0 ? types.remove(g) : types[g] = level;
    final label = groupLabels[g]!;
    notes.add(switch (level) {
      1 => '$label: $r of $n right, so its round is shorter${_joins(g)}',
      -1 => '$label: $r of $n right, so it gets an extra short round',
      _ => old == 1 ? '$label: $r of $n right, so its round is back to full' : '$label: $r of $n right, back to usual',
    });
  }

  return WeekAdapt(pace: pace, step: moved, goodRun: goodRun, types: types, notes: notes);
}

/// Cards of [ids] already practised that are due at [at]. Words never met
/// aren't a backlog.
int _dueStarted(UserStore store, List<String> ids, DateTime at) {
  const sched = Scheduler();
  var n = 0;
  for (final id in ids) {
    for (final d in Direction.values) {
      final c = store.card(id, d);
      if (c != null && sched.isDue(c, at)) n++;
    }
  }
  return n;
}

String _joins(String group) {
  final i = typeGroups.indexOf(group);
  return i + 1 < typeGroups.length ? ' and ${groupLabels[typeGroups[i + 1]]!.toLowerCase()} gets a little more' : '';
}
