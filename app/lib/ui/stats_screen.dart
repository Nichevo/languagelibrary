import 'dart:math';

import 'package:flutter/material.dart';

import '../data/daily.dart';
import '../data/library.dart';
import '../data/user_store.dart';
import '../srs/scheduler.dart';
import 'common.dart';

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
            ],
          ),
        ),
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Practise some cards and your statistics will fill in here.',
                style: theme.textTheme.bodyMedium),
          ),
        section('Time per day', note: 'Last 14 days, in minutes', [
          _Bars(
            values: [
              for (var i = 13; i >= 0; i--) (byDay[today.subtract(Duration(days: i))]?.$1.inSeconds ?? 0) / 60,
            ],
            labels: [
              for (var i = 13; i >= 0; i--) _weekday(today.subtract(Duration(days: i))),
            ],
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
        section('Change over time', note: 'Last 30 days', [
          _Trend(
            store: store,
            today: today,
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

  static String _weekday(DateTime d) => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];

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

  static List<Color> _ratingColors(ThemeData t) {
    final dark = t.brightness == Brightness.dark;
    return dark
        ? const [Color(0xFFE07A72), Color(0xFFD9A43A), Color(0xFF5DBB72), Color(0xFF5FA3E0)]
        : const [Color(0xFFD0453A), Color(0xFFE0A526), Color(0xFF2E9A4A), Color(0xFF2F7FD0)];
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
  const _Bars({required this.values, required this.labels, required this.color});
  final List<double> values;
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
                      Text(values[i] < 1 ? '<1' : values[i].round().toString(),
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
                    Text(labels[i], style: theme.textTheme.labelSmall),
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
  const _Trend({required this.store, required this.today, required this.focusColor, required this.knownColor});
  final UserStore store;
  final DateTime today;
  final Color focusColor;
  final Color knownColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = <double?>[];
    final known = <double?>[];
    for (var i = 29; i >= 0; i--) {
      final s = store.snapshots[dayKey(today.subtract(Duration(days: i)))];
      focus.add(s?.starred.toDouble());
      known.add(s == null
          ? null
          : (s.byStatus[CardStatus.familiar.index] + s.byStatus[CardStatus.strong.index]).toDouble());
    }
    final days = focus.whereType<double>().length;
    if (days < 2) {
      return Text('This fills in as you use the app on different days.', style: theme.textTheme.bodySmall);
    }
    return SizedBox(
      height: 120,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(
          [(focus, focusColor), (known, knownColor)],
          theme.colorScheme.outlineVariant,
          theme.textTheme.labelSmall!,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.lines, this.grid, this.label);
  final List<(List<double?>, Color)> lines;
  final Color grid;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final top = lines.expand((l) => l.$1).whereType<double>().fold<double>(1, max);
    final h = size.height - 14;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h), Offset(size.width, h), gridPaint);
    final tp = TextPainter(text: TextSpan(text: top.round().toString(), style: label), textDirection: TextDirection.ltr)
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
        if (started) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          started = true;
        }
      }
      canvas.drawPath(path, paint);
    }
    final start = TextPainter(text: TextSpan(text: '30 days ago', style: label), textDirection: TextDirection.ltr)
      ..layout();
    start.paint(canvas, Offset(0, size.height - start.height));
    final end = TextPainter(text: TextSpan(text: 'Today', style: label), textDirection: TextDirection.ltr)..layout();
    end.paint(canvas, Offset(size.width - end.width, size.height - end.height));
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}
