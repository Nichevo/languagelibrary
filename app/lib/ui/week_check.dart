import 'package:flutter/material.dart';

import '../data/week_score.dart';
import '../models/journey_week.dart';
import 'common.dart';
import 'drill_screen.dart';
import 'wide.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Runs [week]'s Sunday check, or its check-back with [back], and saves it
/// when every word was answered. Leaving part way through saves nothing, so
/// it can be started again.
Future<void> runCheck(BuildContext context, JourneyWeek week, {bool back = false}) async {
  final store = AppScope.of(context).store;
  final held = heldFor(store, week);
  final answers = <String, bool>{};
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => DrillScreen(
      drill: Drill.listen,
      ids: held.kinds.keys.toList(),
      kinds: held.kinds,
      title: back ? 'Check-back' : 'Week check',
      nextLabel: 'See the score',
      onCheck: (id, right) => answers[id] = right,
    ),
  ));
  if (answers.length >= held.kinds.length) await saveCheck(store, week, answers, DateTime.now(), back: back);
}

/// Three bars: when first met, Sunday and five weeks later. An empty slot
/// shows when it comes, or a dash.
class ScoreBars extends StatelessWidget {
  const ScoreBars({super.key, required this.score, this.height = 64});
  final WeekScore score;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final (backFrom, _) = checkBackWindow(score.week);
    Widget bar(String label, int? value, double alpha, String empty) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(value == null ? empty : '$value%', style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Container(
                height: value == null ? 3 : 4 + (height - 4) * value / 100,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: value == null ? c.outlineVariant : c.primary.withValues(alpha: alpha),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        );
    return SizedBox(
      height: height + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bar('Just met', score.first, 0.4, '–'),
          bar('Sunday', score.sunday, 0.7, 'not checked'),
          bar('5 weeks', score.back, 1, score.held.back == null ? _date(backFrom) : '–'),
        ],
      ),
    );
  }
}

/// Chips for [ids] and a button to practise them now.
class _Slipped extends StatelessWidget {
  const _Slipped({required this.title, required this.ids, this.note});
  final String title;
  final List<String> ids;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.of(context).library;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final id in ids)
            if (lib.byId[id] case final e?) Chip(label: Text(e.simplified), visualDensity: VisualDensity.compact),
        ]),
        if (note != null) Text(note!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DrillScreen(drill: Drill.listen, ids: ids, title: 'Practise these', nextLabel: 'Done'),
          )),
          child: const Text('Practise these'),
        ),
      ],
    );
  }
}

/// On the recap: [week]'s Sunday check to start, or its score once taken.
/// Nothing for a review week or once the check has closed untaken.
class WeekCheckCard extends StatelessWidget {
  const WeekCheckCard({super.key, required this.week});
  final JourneyWeek week;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final held = heldFor(store, week);
    if (held.sunday == null) {
      if (!canCheck(week, now)) return const SizedBox.shrink();
      return _card(context, [
        Text('Week check · ${held.kinds.length} words', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('One question per word, the same kind you had when you met it. No hints. About 2 minutes.'),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => runCheck(context, week), child: const Text('Start check')),
        const SizedBox(height: 4),
        Text('Gives this week\'s score. Skip it and the week just has no score.', style: theme.textTheme.bodySmall),
      ], highlight: true);
    }
    final score = WeekScore(week, held);
    final (kept, of) = score.keptToSunday;
    final right = held.sunday!.values.where((r) => r).length;
    final slipped = wrongIn(held.sunday);
    final (backFrom, _) = checkBackWindow(week);
    return _card(context, [
      Text('This week\'s score: ${score.sunday}%', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      ScoreBars(score: score),
      const SizedBox(height: 6),
      Text([
        '$right of ${held.sunday!.length} right.',
        if (of > 0) 'You kept $kept of the $of you got right when you met them.',
        if (held.first.length < held.kinds.length)
          'Compared with when you met them on ${held.first.length} of ${held.kinds.length} words.',
      ].join(' ')),
      if (slipped.isNotEmpty) _Slipped(title: 'Slipped this week', ids: slipped),
      const SizedBox(height: 6),
      Text('These words are held for a check-back from Sunday ${_date(backFrom)}.', style: theme.textTheme.bodySmall),
    ]);
  }
}

/// [week]'s check-back to start, or how it went once taken.
class CheckBackCard extends StatelessWidget {
  const CheckBackCard({super.key, required this.week});
  final JourneyWeek week;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    final held = heldFor(store, week);
    final score = WeekScore(week, held);
    if (held.back == null) {
      if (!canCheckBack(store, week, DateTime.now())) return const SizedBox.shrink();
      return _card(context, [
        Text('Check-back · ${week.title}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text([
          if (score.sunday != null) '$checkBackWeeks weeks ago it scored ${score.sunday}%.',
          'Same ${held.kinds.length} words, same questions. About 2 minutes.',
        ].join(' ')),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: () => runCheck(context, week, back: true), child: const Text('Start check-back')),
        const SizedBox(height: 4),
        Text('Open all this week, from the week card too.', style: theme.textTheme.bodySmall),
      ]);
    }
    final (kept, of) = score.heldToBack;
    final lost = wrongIn(held.back);
    return _card(context, [
      Text('Check-back · ${week.title}: ${score.back}%', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      ScoreBars(score: score),
      const SizedBox(height: 6),
      if (of > 0) Text('Held $kept of the $of you had ${held.sunday != null ? 'on Sunday' : 'when you met them'}.'),
      if (lost.isNotEmpty)
        _Slipped(
          title: 'Slipped since',
          ids: lost,
          note: 'These come round again in Friday\'s mixed practice for the next two weeks, and first in the next review week.',
        ),
    ]);
  }
}

Widget _card(BuildContext context, List<Widget> children, {bool highlight = false}) {
  final c = Theme.of(context).colorScheme;
  return Card(
    margin: const EdgeInsets.fromLTRB(0, 8, 0, 4),
    color: highlight ? c.primaryContainer : null,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  );
}

/// One week's checks on a screen of their own: from the week card's
/// check-back banner and from Progress.
class WeekScoreScreen extends StatelessWidget {
  const WeekScoreScreen({super.key, required this.week});
  final JourneyWeek week;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final w = store.weeks.where((x) => x.start == week.start).firstOrNull ?? week;
        return Scaffold(
          appBar: AppBar(title: Text(w.title)),
          body: Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                Text('Week of ${_date(w.start)}', style: Theme.of(context).textTheme.bodySmall),
                WeekCheckCard(week: w),
                CheckBackCard(week: w),
                if (w.held?.sunday == null && w.held?.back == null && !canCheck(w, DateTime.now()) &&
                    !canCheckBack(store, w, DateTime.now()))
                  const Padding(padding: EdgeInsets.only(top: 16), child: Text('No checks for this week.')),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// On Progress: each week's three numbers, and whether they are holding up
/// over time.
class StickCard extends StatelessWidget {
  const StickCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    if (!store.journeyOn) return const SizedBox.shrink();
    final scores = weekScores(store);
    if (scores.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final shown = scores.length > 8 ? scores.sublist(scores.length - 8) : scores;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _explain(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('How well words stick', style: theme.textTheme.titleMedium)),
                Icon(Icons.info_outline, size: 18, color: c.onSurfaceVariant),
              ]),
              Text('Each week: just met · Sunday · 5 weeks later', style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              _Trend(scores: shown),
              const SizedBox(height: 6),
              _legend(context),
              const SizedBox(height: 8),
              for (final s in shown.reversed)
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WeekScoreScreen(week: s.week))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(child: Text(s.week.title, overflow: TextOverflow.ellipsis)),
                      Text(
                        [
                          s.first?.toString() ?? '–',
                          s.sunday?.toString() ?? '–',
                          s.back?.toString() ??
                              (s.held.back == null && DateTime.now().isBefore(checkBackWindow(s.week).$1)
                                  ? 'due ${_date(checkBackWindow(s.week).$1)}'
                                  : '–'),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ]),
                  ),
                ),
              if (summary(scores) case final line?) ...[
                const SizedBox(height: 6),
                Text(line, style: theme.textTheme.labelMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    Widget key(String label, double alpha) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, color: c.primary.withValues(alpha: alpha)),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(width: 12),
        ]);
    return Wrap(children: [key('Just met', 0.35), key('Sunday', 0.7), key('5 weeks later', 1)]);
  }

  void _explain(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How well words stick', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Each week\'s words are asked the same kind of question three times: just after you meet '
                    'them on Monday or Tuesday, in the short check on Sunday, and again five weeks later.'),
                const SizedBox(height: 8),
                const Text('The first number is taken seconds after you see each word, so it is usually the highest. '
                    'A lower Sunday number is normal. The one to watch is how much of Sunday\'s score is still there '
                    'five weeks later.'),
                const SizedBox(height: 8),
                const Text('Words that slip at a check-back come round again in Friday\'s mixed practice and first in '
                    'the next review week. Check answers don\'t count towards the week\'s other numbers.'),
              ],
            ),
          ),
        ),
      );
}

/// A line on how the scores are going over time, or null with too few.
String? summary(List<WeekScore> scores) {
  final held = [
    for (final s in scores)
      if (s.heldToBack case (final kept, final of) when of > 0) kept / of,
  ];
  final sundays = [for (final s in scores) ?s.sunday];
  final parts = <String>[];
  if (held.isNotEmpty) {
    final last = held.length > 4 ? held.sublist(held.length - 4) : held;
    final avg = (100 * last.reduce((a, b) => a + b) / last.length).round();
    parts.add('Last ${last.length} check-back${last.length == 1 ? '' : 's'} held $avg% of the words you had.');
  }
  if (sundays.length >= 4) {
    final half = sundays.length ~/ 2;
    double avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
    final before = avg(sundays.sublist(0, half)), after = avg(sundays.sublist(half));
    final diff = (after - before).round();
    parts.add(diff.abs() < 3
        ? 'Sunday scores are steady.'
        : diff > 0
            ? 'Sunday scores are up $diff points on earlier weeks.'
            : 'Sunday scores are down ${-diff} points on earlier weeks.');
  }
  return parts.isEmpty ? null : parts.join(' ');
}

/// Three slim bars a week, oldest on the left, so the trend over time shows.
class _Trend extends StatelessWidget {
  const _Trend({required this.scores});
  final List<WeekScore> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    const h = 60.0;
    Widget slim(int? v, double alpha) => Container(
          width: 6,
          height: v == null ? 2 : 2 + (h - 2) * v / 100,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          color: v == null ? c.outlineVariant : c.primary.withValues(alpha: alpha),
        );
    return SizedBox(
      height: h + 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in scores)
            Flexible(
              child: SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [slim(s.first, 0.35), slim(s.sunday, 0.7), slim(s.back, 1)],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_date(s.week.start), style: theme.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
