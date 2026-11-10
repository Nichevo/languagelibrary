import 'dart:math';

import 'package:flutter/material.dart';

import '../data/daily.dart';
import '../data/library.dart';
import '../data/advice.dart';
import '../data/method_stats.dart';
import '../data/user_store.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'practice_screen.dart';

/// The Progress tab: time spent, how well cards are known, and how that changes.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListenableBuilder(
        listenable: scope.store,
        builder: (context, _) => StatsView(library: scope.library, store: scope.store, now: DateTime.now()),
      ),
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.library, required this.store, required this.now});
  final Library library;
  final UserStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviews = store.reviews;
    final today = dayOf(now);

    // Time and answers per day.
    final byDay = <DateTime, (Duration, int)>{};
    for (final r in reviews) {
      final d = dayOf(r.at);
      final (t, n) = byDay[d] ?? (Duration.zero, 0);
      byDay[d] = (t + r.spent, n + 1);
    }
    final total = reviews.fold(Duration.zero, (t, r) => t + r.spent);
    final week = [
      for (final r in reviews)
        if (!r.at.isBefore(today.subtract(const Duration(days: 6)))) r.spent,
    ].fold(Duration.zero, (t, s) => t + s);
    var streak = 0;
    for (var d = byDay.containsKey(today) ? today : today.subtract(const Duration(days: 1));
        byDay.containsKey(d);
        d = d.subtract(const Duration(days: 1))) {
      streak++;
    }

    final period = Period.byName(store.statsPeriod);
    final labels = period.labels(today);
    final buckets = byPeriod(reviews, today, period: period);

    // Each word's current run of right answers.
    final runs = rightInARow(reviews);

    // Cards by status, now.
    final status = List.filled(CardStatus.values.length, 0);
    for (final id in store.starred) {
      for (final d in Direction.values) {
        status[CardStatus.of(store.card(id, d)).index]++;
      }
    }

    // Answers in the last 30 days.
    final recent = [
      for (final r in reviews)
        if (!r.at.isBefore(today.subtract(const Duration(days: 29)))) r,
    ];
    final ratings = List.filled(Rating.values.length, 0);
    for (final r in recent) {
      ratings[r.rating.index]++;
    }

    // Only the levels switched on in Settings, so the bars aren't swamped.
    final entries = library.entries.where(store.shows).toList();
    final words = entries.where((e) => !e.isSentence).length;
    final sentences = entries.length - words;
    final starredSet = store.starred.toSet();

    Widget section(String title, List<Widget> children, {String? note}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tile('Time practising', _duration(total)),
              _Tile('Last 7 days', _duration(week)),
              _Tile('Cards answered', '${reviews.length}'),
              _Tile('Days in a row', '$streak'),
              _Tile('Words right 3+ in a row', '${runs.values.where((n) => n >= 3).length}'),
            ],
          ),
        ),
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Practise some cards and your statistics will fill in here.',
                style: theme.textTheme.bodyMedium),
          ),
        () {
          final focus = tips(store, now);
          final noticed = trends(reviews, now);
          if (reviews.isEmpty) return const SizedBox.shrink();
          void act(TipAction a) {
            final ids = switch (a) {
              TipAction.practiseTricky => [
                  for (final (id, _, _) in trickyWords(reviews, today.subtract(const Duration(days: 59))))
                    if (library.byId[id] != null) id,
                ],
              TipAction.practiseDue => null,
            };
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ids == null ? const PracticeScreen() : PracticeScreen(ids: ids, includeNotDue: true),
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TipCard(
                title: 'Where to focus',
                icon: Icons.flag_outlined,
                empty: 'Nothing stands out right now. Keep going as you are.',
                tips: focus,
                onAction: act,
              ),
              _TipCard(
                title: 'Trends we noticed',
                icon: Icons.insights_outlined,
                empty: 'No clear patterns yet. These show up after a couple of weeks of practice.',
                tips: noticed,
                note: 'Each one compares your own answers, and only shows when the difference is clear.',
              ),
            ],
          );
        }(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Text('Charts by', style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<Period>(
                  showSelectedIcon: false,
                  segments: [for (final p in Period.values) ButtonSegment(value: p, label: Text(p.label))],
                  selected: {period},
                  onSelectionChanged: (s) => store.setStatsPeriod(s.first.name),
                ),
              ),
            ],
          ),
        ),
        section('Time practising', note: '${period.span}, in minutes', [
          _Bars(
            values: [for (final b in buckets) b.fold(Duration.zero, (t, r) => t + r.spent).inSeconds / 60],
            labels: labels,
            color: theme.colorScheme.primary,
          ),
        ]),
        section('Cards by status', note: 'Both cards of each Focus word', [
          _Stacked(
            values: status,
            colors: _statusColors(theme),
          ),
          const SizedBox(height: 8),
          for (final s in CardStatus.values)
            _Legend(
              color: _statusColors(theme)[s.index],
              label: s.label,
              detail: s.meaning,
              value: '${status[s.index]}',
            ),
        ]),
        section('Change over time', note: period.span, [
          _Trend(
            store: store,
            today: today,
            period: period,
            focusColor: theme.colorScheme.tertiary,
            knownColor: _statusColors(theme)[CardStatus.strong.index],
          ),
          const SizedBox(height: 6),
          _Legend(color: theme.colorScheme.tertiary, label: 'Words in Focus', value: '${store.starred.length}'),
          _Legend(
            color: _statusColors(theme)[CardStatus.strong.index],
            label: 'Cards familiar or strong',
            value: '${status[CardStatus.familiar.index] + status[CardStatus.strong.index]}',
          ),
        ]),
        section('Library and Focus', [
          _Ratio('Whole library', store.starred.length, entries.length, theme.colorScheme.primary),
          _Ratio('Words and phrases', entries.where((e) => !e.isSentence && starredSet.contains(e.id)).length,
              words, theme.colorScheme.primary),
          _Ratio('Sentences', entries.where((e) => e.isSentence && starredSet.contains(e.id)).length,
              sentences, theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text('By topic', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          for (final t in Library.topics)
            _Ratio(
              topicLabel(t),
              entries.where((e) => e.topics.contains(t) && starredSet.contains(e.id)).length,
              entries.where((e) => e.topics.contains(t)).length,
              theme.colorScheme.secondary,
            ),
        ]),
        section('How you answered', note: 'Last 30 days, ${recent.length} cards', [
          _Stacked(values: ratings, colors: _ratingColors(theme)),
          const SizedBox(height: 8),
          for (final r in Rating.values)
            _Legend(
              color: _ratingColors(theme)[r.index],
              label: _ratingName(r),
              value: recent.isEmpty ? '0' : '${(100 * ratings[r.index] / recent.length).round()}%',
            ),
        ]),
        () {
          final methods = methodStats(reviews, today.subtract(const Duration(days: 29)));
          final best = bestMethod(methods);
          final used = [for (final m in methods) if (m.answers > 0) m];
          final tested = [for (final m in methods) if (m.tested > 0) m];
          return section('Practice methods', note: 'Last 30 days', [
            if (used.isEmpty) Text('No answers yet.', style: theme.textTheme.bodyMedium),
            for (final m in used)
              _MethodRow(
                label: m.label,
                detail: '${m.answers} answers · ${(100 * m.rightRate!).round()}% right · ${_duration(m.time)}',
                value: m.rightRate!,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(height: 8),
            Text('What helps you remember', style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              'How often a word was remembered on its next flashcard, by how you practised it in between. '
              'Flashcards ask from memory, so they are the fair test.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (best != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  best.method == 'cards'
                      ? 'So far, flashcards alone work best for you.'
                      : 'So far, "${best.label}" helps you remember best.',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            for (final m in tested)
              _MethodRow(
                label: m.method == 'cards' ? 'Flashcards alone' : m.label,
                detail: m.tested < minTested
                    ? '${m.tested} so far, ${minTested - m.tested} more to compare'
                    : '${(100 * m.rememberRate!).round()}% remembered (${m.tested})',
                value: m.tested < minTested ? 0 : m.rememberRate!,
                color: m == best ? _statusColors(theme)[CardStatus.strong.index] : theme.colorScheme.secondary,
              ),
            if (tested.isEmpty)
              Text('Practise some words a few ways, then do their flashcards, and this will fill in.',
                  style: theme.textTheme.bodyMedium),
          ]);
        }(),
        () {
          final lately = {
            for (final r in recent)
              ?r.id,
          };
          final buckets = List.filled(4, 0);
          for (final id in lately) {
            final n = runs[id] ?? 0;
            buckets[n == 0 ? 0 : n < 3 ? 1 : n < 5 ? 2 : 3]++;
          }
          final colors = _ratingColors(theme);
          final runColors = [colors[0], colors[1], colors[3], colors[2]];
          const runLabels = ['Missed last time', '1 or 2 in a row', '3 or 4 in a row', '5 or more in a row'];
          final top = [
            for (final e in runs.entries)
              if (e.value > 0 && library.byId[e.key] != null) (library.byId[e.key]!, e.value),
          ]..sort((a, b) => b.$2.compareTo(a.$2));
          return section(
            'Right in a row',
            note: 'Words you practised in the last 30 days, by how many times in a row you have got each one right, '
                'by any practice method. A wrong answer starts it again at 0.',
            [
              if (lately.isEmpty)
                Text('No words practised lately.', style: theme.textTheme.bodyMedium)
              else ...[
                _Stacked(values: buckets, colors: runColors),
                const SizedBox(height: 8),
                for (var i = 0; i < 4; i++) _Legend(color: runColors[i], label: runLabels[i], value: '${buckets[i]}'),
              ],
              if (top.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Longest runs now', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                for (final (e, n) in top.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(e.simplified, style: theme.textTheme.titleMedium),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.pinyin,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('$n in a row', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ],
          );
        }(),
        () {
          final weeks = methodWeeks(reviews, today, period: period);
          final used = [
            for (final m in {...methodLabels.keys, for (final w in weeks) ...w.keys})
              if (weeks.any((w) => w.containsKey(m))) m,
          ];
          final colors = _methodColors(theme);
          Color colorOf(String m) {
            final i = methodLabels.keys.toList().indexOf(m);
            return colors[(i < 0 ? used.indexOf(m) : i) % colors.length];
          }

          final last = weeks.last;
          return section('Practice methods over time', note: 'Answers each ${period.name}, ${period.span.toLowerCase()}', [
            if (used.isEmpty)
              Text('No answers yet.', style: theme.textTheme.bodyMedium)
            else ...[
              _StackedBars(
                values: [
                  for (final w in weeks) [for (final m in used) (w[m]?.answers ?? 0).toDouble()],
                ],
                colors: [for (final m in used) colorOf(m)],
                labels: labels,
              ),
              const SizedBox(height: 16),
              Text('Share right by method', style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text('Each ${period.name} with at least $minWeekAnswers answers that way', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              _WeekLine(
                period: period,
                lines: [
                  for (final m in used)
                    (
                      [
                        for (final w in weeks)
                          if (w[m] case final c? when c.answers >= minWeekAnswers) 100 * c.right / c.answers else null,
                      ],
                      colorOf(m),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final m in used)
                _Legend(
                  color: colorOf(m),
                  label: methodLabels[m] ?? m,
                  detail: period.current,
                  value: last[m] == null
                      ? '–'
                      : '${(100 * last[m]!.right / last[m]!.answers).round()}% of ${last[m]!.answers}',
                ),
            ],
          ]);
        }(),
        () {
          final weeks = buckets;
          final memory = [for (final w in weeks) countOf(w, isRecall)];
          final speed = [
            for (final w in weeks)
              w.isEmpty ? 0.0 : w.fold(Duration.zero, (t, r) => t + r.spent).inMilliseconds / 1000 / w.length,
          ];
          final learned = List.filled(weeks.length, 0.0);
          for (final at in store.firstKnown.values) {
            if (at != UserStore.unknownDate) {
              if (period.indexOf(at, today) case final w?) learned[w]++;
            }
          }
          final good = _statusColors(theme)[CardStatus.strong.index];
          return section('Over time', note: period.span, [
            Text('Flashcards remembered', style: theme.textTheme.labelLarge),
            Text('Share of flashcards you remembered, on words you had seen before', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            _WeekLine(
                period: period,
              lines: [
                (
                  [for (final c in memory) c.answers >= minWeekAnswers ? 100 * c.right / c.answers : null],
                  good,
                ),
              ],
            ),
            _Legend(
              color: good,
              label: period.endLabel,
              value: memory.last.answers == 0
                  ? '–'
                  : '${(100 * memory.last.right / memory.last.answers).round()}% of ${memory.last.answers}',
            ),
            const SizedBox(height: 16),
            Text('Seconds per answer', style: theme.textTheme.labelLarge),
            Text('Average time on each answer, all practice methods. Faster usually means it is sinking in.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            _Bars(values: speed, labels: labels, color: theme.colorScheme.primary, decimals: true),
            const SizedBox(height: 16),
            Text('Cards learned', style: theme.textTheme.labelLarge),
            Text('Cards that became Familiar (back in a week or more) for the first time', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            _Bars(values: learned, labels: labels, color: good),
          ]);
        }(),
        () {
          final weeks = buckets;
          final listen = [for (final w in weeks) countOf(w, isListening)];
          final read = [for (final w in weeks) countOf(w, isReading)];
          final colors = _methodColors(theme);
          final l30 = countOf(recent, isListening), r30 = countOf(recent, isReading);
          String share(WeekCount c) => c.answers == 0 ? '–' : '${(100 * c.right / c.answers).round()}% of ${c.answers}';
          return section('Listening and reading', note: 'Share right each ${period.name}, ${period.span.toLowerCase()}', [
            if (l30.answers == 0 && r30.answers == 0 && listen.every((c) => c.answers == 0))
              Text('Practise with "Hear it, pick the word" and the "See it" questions, and this will fill in.',
                  style: theme.textTheme.bodyMedium)
            else ...[
              _WeekLine(
                period: period,
                lines: [
                  ([for (final c in listen) c.answers >= minWeekAnswers ? 100 * c.right / c.answers : null], colors[0]),
                  ([for (final c in read) c.answers >= minWeekAnswers ? 100 * c.right / c.answers : null], colors[1]),
                ],
              ),
              const SizedBox(height: 6),
              _Legend(color: colors[0], label: 'Listening', detail: 'hear it, pick the word · 30 days', value: share(l30)),
              _Legend(color: colors[1], label: 'Reading', detail: 'see it, pick the answer · 30 days', value: share(r30)),
            ],
          ]);
        }(),
        () {
          final tricky = [
            for (final (id, misses, answers) in trickyWords(reviews, today.subtract(const Duration(days: 59))))
              if (library.byId[id] case final e?) (e, misses, answers),
          ];
          return section('Words that trip you up', note: 'Missed twice or more in the last 60 days', [
            if (tricky.isEmpty)
              Text('Nothing yet. Words you miss more than once will show here.', style: theme.textTheme.bodyMedium)
            else ...[
              for (final (e, misses, answers) in tricky)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(e.simplified, style: theme.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.pinyin}  ${e.gloss}',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('missed $misses of $answers', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Practise these'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PracticeScreen(ids: [for (final (e, _, _) in tricky) e.id], includeNotDue: true),
                )),
              ),
            ],
          ]);
        }(),
        section('Your own scores', note: 'Easy / OK / Hard on word pages', [
          for (final d in Difficulty.values)
            _Legend(
              color: theme.colorScheme.outline,
              label: d.label,
              value: '${store.difficulty.values.where((x) => x == d).length}',
            ),
        ]),
      ],
    );
  }

  static String _duration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} s';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  static String _ratingName(Rating r) => switch (r) {
        Rating.again => 'Again',
        Rating.hard => 'Hard',
        Rating.good => 'Good',
        Rating.easy => 'Easy',
      };

  static List<Color> _statusColors(ThemeData t) {
    final dark = t.brightness == Brightness.dark;
    return dark
        ? const [Color(0xFF6B6B6B), Color(0xFFD9A43A), Color(0xFF5FA3E0), Color(0xFF5DBB72)]
        : const [Color(0xFFBDBDBD), Color(0xFFE0A526), Color(0xFF2F7FD0), Color(0xFF2E9A4A)];
  }

  /// One colour per practice method, in [methodLabels] order.
  static List<Color> _methodColors(ThemeData t) {
    final dark = t.brightness == Brightness.dark;
    return dark
        ? const [
            Color(0xFF5FA3E0),
            Color(0xFFE0A526),
            Color(0xFF5DBB72),
            Color(0xFFE07A72),
            Color(0xFFB08CE0),
            Color(0xFF4FC1C1),
            Color(0xFFE08CC0),
            Color(0xFFB0B0B0),
            Color(0xFFC7C25A),
          ]
        : const [
            Color(0xFF2F7FD0),
            Color(0xFFC98A0C),
            Color(0xFF2E9A4A),
            Color(0xFFD0453A),
            Color(0xFF7B52C7),
            Color(0xFF16908F),
            Color(0xFFC2408F),
            Color(0xFF6B6B6B),
            Color(0xFF8A7F00),
          ];
  }

  static List<Color> _ratingColors(ThemeData t) {
    final dark = t.brightness == Brightness.dark;
    return dark
        ? const [Color(0xFFE07A72), Color(0xFFD9A43A), Color(0xFF5DBB72), Color(0xFF5FA3E0)]
        : const [Color(0xFFD0453A), Color(0xFFE0A526), Color(0xFF2E9A4A), Color(0xFF2F7FD0)];
  }
}

/// A card of suggestions or noticed trends at the top of Progress.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.title,
    required this.icon,
    required this.empty,
    required this.tips,
    this.note,
    this.onAction,
  });
  final String title;
  final IconData icon;
  final String empty;
  final String? note;
  final List<Tip> tips;
  final void Function(TipAction)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: theme.textTheme.titleMedium),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              if (tips.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(empty, style: theme.textTheme.bodyMedium),
                ),
              for (final t in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(t.detail, style: theme.textTheme.bodyMedium),
                      if (t.action case final a? when onAction != null)
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => onAction!(a),
                          child: Text(a == TipAction.practiseTricky ? 'Practise these words' : 'Practise now'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.sizeOf(context).width - 32 - 8) / 2;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value, this.detail});
  final Color color;
  final String label;
  final String? detail;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label, style: theme.textTheme.bodyMedium),
                if (detail != null) TextSpan(text: '  $detail', style: theme.textTheme.bodySmall),
              ]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A row of bars with a label under each and the value above the tallest.
class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.labels, required this.color, this.decimals = false});
  final List<double> values;

  /// Show values with one decimal place.
  final bool decimals;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = values.fold<double>(0, max);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text(softWrap: false, decimals ? values[i].toStringAsFixed(1) : values[i] < 1 ? '<1' : values[i].round().toString(),
                          style: theme.textTheme.labelSmall, maxLines: 1),
                    const SizedBox(height: 2),
                    Container(
                      height: top == 0 ? 0 : max(2, 80 * values[i] / top),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(labels[i], style: theme.textTheme.labelSmall, maxLines: 1),
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

/// A row of bars, each split into coloured parts, with a label under each and
/// its total above it.
class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.values, required this.colors, required this.labels});

  /// For each bar, one value per colour.
  final List<List<double>> values;
  final List<Color> colors;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = [for (final v in values) v.fold<double>(0, (a, b) => a + b)];
    final top = totals.fold<double>(0, max);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (totals[i] > 0) Text('${totals[i].round()}', style: theme.textTheme.labelSmall, maxLines: 1),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      child: Column(
                        children: [
                          for (var j = values[i].length - 1; j >= 0; j--)
                            if (values[i][j] > 0)
                              Container(height: top == 0 ? 0 : 84 * values[i][j] / top, color: colors[j]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(labels[i], style: theme.textTheme.labelSmall, maxLines: 1),
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

/// One bar split into parts, for shares of a whole.
class _Stacked extends StatelessWidget {
  const _Stacked({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = values.fold(0, (a, b) => a + b);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 18,
        child: total == 0
            ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
            : Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    if (values[i] > 0)
                      Expanded(
                        flex: values[i],
                        child: Container(
                          color: colors[i],
                          margin: EdgeInsets.only(right: i == values.length - 1 ? 0 : 1),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.label, required this.detail, required this.value, required this.color});
  final String label;
  final String detail;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(detail, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value, color: color, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ],
      ),
    );
  }
}

class _Ratio extends StatelessWidget {
  const _Ratio(this.label, this.part, this.whole, this.color);
  final String label;
  final int part;
  final int whole;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text('$part of $whole in Focus', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: whole == 0 ? 0 : part / whole,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// Two lines over the last 30 days, from the daily snapshots.
class _Trend extends StatelessWidget {
  const _Trend(
      {required this.store, required this.today, required this.period, required this.focusColor, required this.knownColor});
  final UserStore store;
  final DateTime today;
  final Period period;
  final Color focusColor;
  final Color knownColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The last snapshot in each day, week or month.
    final latest = List<(String, Snapshot)?>.filled(period.count, null);
    store.snapshots.forEach((key, s) {
      final day = DateTime.tryParse(key);
      if (day == null) return;
      if (period.indexOf(day, today) case final i?) {
        if (latest[i] == null || latest[i]!.$1.compareTo(key) < 0) latest[i] = (key, s);
      }
    });
    final focus = [for (final l in latest) l?.$2.starred.toDouble()];
    final known = [
      for (final l in latest)
        l == null ? null : (l.$2.byStatus[CardStatus.familiar.index] + l.$2.byStatus[CardStatus.strong.index]).toDouble(),
    ];
    final days = focus.whereType<double>().length;
    if (days < 2) {
      return Text('This fills in as you use the app over more ${period.name}s.', style: theme.textTheme.bodySmall);
    }
    return SizedBox(
      height: 120,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(
          [(focus, focusColor), (known, knownColor)],
          theme.colorScheme.outlineVariant,
          theme.textTheme.labelSmall!,
          startLabel: period.startLabel,
          endLabel: period.endLabel,
          dots: true,
        ),
      ),
    );
  }
}

/// Shares (0 to 100%) over the chosen days, weeks or months, one line per colour.
class _WeekLine extends StatelessWidget {
  const _WeekLine({required this.lines, required this.period});
  final List<(List<double?>, Color)> lines;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 130,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(
          lines,
          theme.colorScheme.outlineVariant,
          theme.textTheme.labelSmall!,
          top: 100,
          topLabel: '100%',
          startLabel: period.startLabel,
          endLabel: period.endLabel,
          dots: true,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(
    this.lines,
    this.grid,
    this.label, {
    this.top,
    this.topLabel,
    this.startLabel = '30 days ago',
    this.endLabel = 'Today',
    this.dots = false,
  });
  final List<(List<double?>, Color)> lines;
  final Color grid;
  final TextStyle label;

  /// The value at the top of the chart; the largest value when null.
  final double? top;
  final String? topLabel;
  final String startLabel;
  final String endLabel;

  /// Draw a dot on each point, so a value with no neighbour still shows.
  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    final top = this.top ?? lines.expand((l) => l.$1).whereType<double>().fold<double>(1, max);
    final h = size.height - 14;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h), Offset(size.width, h), gridPaint);
    final tp = TextPainter(text: TextSpan(text: topLabel ?? top.round().toString(), style: label), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset.zero);
    canvas.drawLine(Offset(tp.width + 4, tp.height / 2), Offset(size.width, tp.height / 2), gridPaint);
    final n = lines.first.$1.length;
    for (final (values, color) in lines) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        final p = Offset(size.width * i / (n - 1), tp.height / 2 + (h - tp.height / 2) * (1 - v / top));
        if (dots) canvas.drawCircle(p, 3, Paint()..color = color);
        if (started) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
    final start = TextPainter(text: TextSpan(text: startLabel, style: label), textDirection: TextDirection.ltr)
      ..layout();
    start.paint(canvas, Offset(0, size.height - start.height));
    final end = TextPainter(text: TextSpan(text: endLabel, style: label), textDirection: TextDirection.ltr)..layout();
    end.paint(canvas, Offset(size.width - end.width, size.height - end.height));
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}
