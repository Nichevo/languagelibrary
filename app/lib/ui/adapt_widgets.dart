import 'dart:math';

import 'package:flutter/material.dart';

import '../data/adapt.dart';
import '../data/journey.dart';
import '../models/journey_week.dart';
import 'common.dart';

/// A small coloured label for a practice type's level or a change.
class LevelPill extends StatelessWidget {
  const LevelPill(this.text, this.direction, {super.key});
  final String text;

  /// 1 up or easy, 0 the same, -1 down or needs more.
  final int direction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (direction) {
      1 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      -1 => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

String levelName(int level) => switch (level) {
      1 => 'Easy for you',
      -1 => 'Needs more',
      _ => 'Working on it',
    };

/// On the week recap: how the week felt, and how next week is adjusted to it,
/// with the choice to keep last week's settings. A recap opened after the
/// week is over shows how this week was adjusted.
class NextWeekPanel extends StatelessWidget {
  const NextWeekPanel({super.key, required this.week, required this.nextStart, this.finished = false});
  final JourneyWeek week;
  final DateTime nextStart;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    final theme = Theme.of(context);
    if (!store.adaptOn || week.isReview) return const SizedBox.shrink();
    final adapt = finished ? store.weekAt(DateTime.now())?.adapt : adaptFor(store, nextStart);
    final check = checkWeek(store, week, nextStart);
    final base = week.adapt?.pace ?? store.journeyPace;
    Future<void> changed() => replanNext(lib, store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!finished && store.askFeel) ...[
          const SizedBox(height: 12),
          Text('How did the week feel?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final (f, label) in const [('much', 'Too much'), ('right', 'About right'), ('little', 'Too little')])
                ChoiceChip(
                  label: Text(label),
                  selected: week.feel == f,
                  onSelected: (on) async {
                    await store.setWeekFeel(week.start, on ? f : null);
                    await changed();
                  },
                ),
            ],
          ),
        ],
        if (adapt != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(finished ? 'This week' : 'Next week', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(child: Text('New words')),
                      LevelPill(adapt.pace == base ? '${adapt.pace}, the same' : '$base → ${adapt.pace}', adapt.pace.compareTo(base)),
                    ],
                  ),
                  if (check.answers > 0)
                    Text(
                      '${check.percent}% right over ${check.days} ${check.days == 1 ? 'day' : 'days'}, ${check.due} cards due'
                      '${check.olderCounts ? ', ${check.olderRight} of ${check.olderAnswered} words from the week before remembered' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  for (final g in typeGroups)
                    if ((check.groups[g]?.$2 ?? 0) > 0 || adapt.typeLevel(g) != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                check.groups[g] == null
                                    ? groupLabels[g]!
                                    : '${groupLabels[g]} · ${check.groups[g]!.$1} of ${check.groups[g]!.$2}',
                              ),
                            ),
                            LevelPill(levelName(adapt.typeLevel(g)), adapt.typeLevel(g)),
                          ],
                        ),
                      ),
                  if (adapt.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final n in adapt.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(n, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      ),
                  ],
                  Text('Hard practices (typing pinyin, saying words) stay at $hardCap words a day at most.',
                      style: theme.textTheme.bodySmall),
                  if (!finished && (adapt.notes.isNotEmpty || week.keepNext))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          await store.setKeepNext(week.start, !week.keepNext);
                          await changed();
                        },
                        child: Text(week.keepNext ? 'Use the changes' : 'Keep last week\'s'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// On Progress: the number of new words a week the adjusting has found, and
/// where each practice type stands.
class LearningRateCard extends StatelessWidget {
  const LearningRateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    if (!store.journeyOn || !store.adaptOn) return const SizedBox.shrink();
    final weeks = [for (final w in store.weeks) if (w.adapt != null) w];
    if (weeks.isEmpty) return const SizedBox.shrink();
    final shown = weeks.length > 12 ? weeks.sublist(weeks.length - 12) : weeks;
    final latest = weeks.last.adapt!;
    final most = shown.map((w) => w.adapt!.pace).reduce(max);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _explain(context, latest.pace),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Your learning rate', style: theme.textTheme.titleMedium)),
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            Text('New words a week, adjusted to how each week went', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            // One narrow bar a week, oldest on the left, so a single week
            // reads as a chart and not as a button.
            SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, w) in shown.indexed)
                    Flexible(
                      child: SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${w.adapt!.pace}', style: theme.textTheme.labelSmall),
                          Container(
                            width: 22,
                            height: 48 * w.adapt!.pace / most,
                            decoration: BoxDecoration(
                              color: i == shown.length - 1 ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.45),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${w.start.day} ${months[w.start.month - 1]}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Now ${latest.pace} new words a week', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            for (final g in typeGroups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(groupLabels[g]!)),
                    LevelPill(levelName(latest.typeLevel(g)), latest.typeLevel(g)),
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _explain(BuildContext context, int pace) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your learning rate', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Each bar is one week: how many new words that week brought in. The date under it is the '
                      'Monday the week started. A new bar appears each week.'),
                  const SizedBox(height: 8),
                  Text('When a new week starts, the app looks at how the last one went. After a good week it can '
                      'add a word or two, and after a hard one, or with lots of cards still due, it takes some away. '
                      'Right now it is $pace new words a week.'),
                  const SizedBox(height: 8),
                  Text('The labels show how each kind of practice is going: "Easy for you" gets a shorter round, '
                      '"Needs more" gets an extra short round, and "Working on it" stays as usual.'),
                  const SizedBox(height: 8),
                  Text('You can change the number, or turn adjusting off, in Settings > Learning journey.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      );
}
