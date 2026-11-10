import '../srs/scheduler.dart';
import 'method_stats.dart';
import 'user_store.dart';

/// One thing the Progress tab suggests working on, worked out from the
/// learner's own answers. [action] says what its button does, if it has one.
class Tip {
  const Tip(this.title, this.detail, {this.action});
  final String title;
  final String detail;
  final TipAction? action;
}

enum TipAction { practiseTricky, practiseDue }

/// The fewest answers a tip looks at before it says anything, so a handful of
/// unlucky answers doesn't start one.
const minForTip = 20;

/// Up to [limit] suggestions, most useful first, from the last 30 days.
/// Each rule is simple and says what it is based on, so it can be checked.
List<Tip> tips(UserStore store, DateTime now, {int limit = 3}) {
  final reviews = store.reviews;
  final since = now.subtract(const Duration(days: 30));
  final recent = [for (final r in reviews) if (!r.at.isBefore(since)) r];
  final out = <Tip>[];
  String pct(WeekCount c) => '${(100 * c.right / c.answers).round()}%';

  // Away for a while.
  if (reviews.isNotEmpty) {
    final days = now.difference(reviews.last.at).inDays;
    if (days >= 3) {
      out.add(Tip(
        'It has been $days days since you practised',
        'Cards slip the longer they wait. Even five minutes today keeps them from piling up.',
        action: TipAction.practiseDue,
      ));
    }
  }

  // Studied cards waiting.
  const sched = Scheduler();
  final overdue = store.cards.values.where((c) => sched.isDue(c, now)).length;
  if (overdue >= 2 * store.sessionSize && overdue >= 20) {
    out.add(Tip(
      '$overdue cards are waiting for review',
      'Clear these before starring new words. Reviewing on time is what makes words stick.',
      action: TipAction.practiseDue,
    ));
  }

  // Flashcards forgotten too often.
  final recall = countOf(recent, isRecall);
  if (recall.answers >= minForTip && recall.right / recall.answers < 0.8) {
    out.add(Tip(
      'You remembered ${pct(recall)} of your flashcards',
      'Below about 80% usually means new words are coming in faster than they settle. '
          'Star fewer new words for a few days and let reviews catch up.',
    ));
  }

  // Listening behind reading.
  final listen = countOf(recent, isListening), read = countOf(recent, isReading);
  if (listen.answers >= minForTip && read.answers >= minForTip) {
    final gap = read.right / read.answers - listen.right / listen.answers;
    if (gap >= 0.15) {
      out.add(Tip(
        'Your listening is behind your reading',
        'You got ${pct(listen)} right by ear and ${pct(read)} by sight. '
            'Try more "Hear it, pick the word", or set card fronts to include audio.',
      ));
    } else if (gap <= -0.15) {
      out.add(Tip(
        'Your reading is behind your listening',
        'You got ${pct(read)} right by sight and ${pct(listen)} by ear. '
            'Try "See it, pick the meaning" with characters on the front.',
      ));
    }
  }

  // Words missed again and again.
  final tricky = trickyWords(reviews, now.subtract(const Duration(days: 59)), limit: 50);
  if (tricky.length >= 3) {
    out.add(Tip(
      '${tricky.length} words keep tripping you up',
      'Practise just these for a few minutes. They are listed under "Words that trip you up".',
      action: TipAction.practiseTricky,
    ));
  }

  // The hardest way of practising.
  final methods = [
    for (final m in methodStats(reviews, since))
      if (m.answers >= minForTip && m.rightRate! < 0.7) m,
  ]..sort((a, b) => a.rightRate!.compareTo(b.rightRate!));
  if (methods.isNotEmpty) {
    final m = methods.first;
    out.add(Tip(
      '"${m.label}" is your hardest way to practise',
      '${(100 * m.rightRate!).round()}% right in the last 30 days. '
          'A few minutes of it most days helps more than one long go.',
    ));
  }

  return out.take(limit).toList();
}

/// Patterns in the learner's answers that are hard to see in the charts.
/// Each one compares two groups of their own answers, and only speaks up
/// when both groups have enough answers and the difference is clear.
List<Tip> trends(List<Review> reviews, DateTime now) {
  final out = <Tip>[];
  final since = now.subtract(const Duration(days: 60));
  final recent = [for (final r in reviews) if (!r.at.isBefore(since)) r];
  String pct(WeekCount c) => '${(100 * c.right / c.answers).round()}%';
  double rate(WeekCount c) => c.right / c.answers;

  // Time of day.
  // Hours after midnight count as late night (24 to 28).
  int hour(Review r) => r.at.hour < 5 ? r.at.hour + 24 : r.at.hour;
  const parts = [('morning', 5, 12), ('afternoon', 12, 17), ('evening', 17, 22), ('late at night', 22, 29)];
  final byPart = [
    for (final (name, from, to) in parts) (name, countOf(recent, (r) => hour(r) >= from && hour(r) < to)),
  ].where((p) => p.$2.answers >= minForTip).toList()
    ..sort((a, b) => rate(b.$2).compareTo(rate(a.$2)));
  if (byPart.length >= 2 && rate(byPart.first.$2) - rate(byPart.last.$2) >= 0.12) {
    final (best, b) = byPart.first;
    final (worst, w) = byPart.last;
    out.add(Tip(
      'You do best in the $best',
      '${pct(b)} right in the $best, ${pct(w)} ${worst == 'late at night' ? worst : 'in the $worst'} (last 60 days). '
          'If you can, do your harder practice in the $best.',
    ));
  }

  // Getting tired in long sessions: answers less than 30 minutes apart are one session.
  final early = <Review>[], late = <Review>[];
  var n = 0;
  for (var i = 0; i < recent.length; i++) {
    n = i > 0 && recent[i].at.difference(recent[i - 1].at).inMinutes < 30 ? n + 1 : 0;
    if (n < 15) early.add(recent[i]);
    if (n >= 30) late.add(recent[i]);
  }
  final e = countOf(early, (_) => true), l = countOf(late, (_) => true);
  if (e.answers >= minForTip && l.answers >= minForTip && rate(e) - rate(l) >= 0.1) {
    out.add(Tip(
      'You get less right late in long sessions',
      '${pct(e)} right in your first 15 answers, ${pct(l)} after 30 in a row. '
          'Shorter sessions, or a break after about 20 minutes, may help.',
    ));
  }

  // Memory, this fortnight against the one before.
  final cut = now.subtract(const Duration(days: 14)), before = now.subtract(const Duration(days: 28));
  final now2 = countOf(reviews, (r) => isRecall(r) && !r.at.isBefore(cut));
  final then2 = countOf(reviews, (r) => isRecall(r) && !r.at.isBefore(before) && r.at.isBefore(cut));
  if (now2.answers >= minForTip && then2.answers >= minForTip) {
    final change = rate(now2) - rate(then2);
    if (change >= 0.08) {
      out.add(Tip('Your memory is getting better',
          'You remembered ${pct(now2)} of flashcards in the last two weeks, up from ${pct(then2)} the two weeks before.'));
    } else if (change <= -0.08) {
      out.add(Tip('You are forgetting more than before',
          'You remembered ${pct(now2)} of flashcards in the last two weeks, down from ${pct(then2)} the two weeks before. '
              'This often happens after adding a lot of new words at once.'));
    }
  }

  // Speed, on answers you got right.
  double secs(Iterable<Review> rs) => rs.fold(0, (t, r) => t + r.spent.inMilliseconds) / 1000 / rs.length;
  final fast = [for (final r in reviews) if (r.right && !r.at.isBefore(cut)) r];
  final slow = [for (final r in reviews) if (r.right && !r.at.isBefore(before) && r.at.isBefore(cut)) r];
  if (fast.length >= minForTip && slow.length >= minForTip) {
    final a = secs(fast), b = secs(slow);
    if (b > 0 && a <= 0.8 * b) {
      out.add(Tip('You are answering faster',
          '${a.toStringAsFixed(1)} s per right answer in the last two weeks, down from ${b.toStringAsFixed(1)} s. '
              'Words that come quicker are sinking in.'));
    }
  }

  // New words against ones you have known a while: is anything sticking?
  final firstSeen = <String, DateTime>{};
  for (final r in reviews) {
    if (r.id case final id?) firstSeen.putIfAbsent(id, () => r.at);
  }
  final newer = countOf(recent, (r) => r.id != null && r.at.difference(firstSeen[r.id]!).inDays < 7);
  final older = countOf(recent, (r) => r.id != null && r.at.difference(firstSeen[r.id]!).inDays >= 21);
  if (newer.answers >= minForTip && older.answers >= minForTip && rate(older) - rate(newer) >= 0.2) {
    out.add(Tip('New words take you a while',
        '${pct(newer)} right on words in their first week, ${pct(older)} once you have had them three weeks. '
            'That is normal: new words settle with a few reviews, so keep them coming back.'));
  }

  return out;
}
