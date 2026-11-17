import 'dart:math';

import 'package:flutter/material.dart';

import '../data/conversations.dart';
import '../data/daily.dart';
import '../data/talk.dart';
import 'conversation_screen.dart';
import 'talk_review.dart';

/// "Your conversations" on Progress: this week, said well by week, each scene
/// you've tried with when it's due again, and the sounds that most often come
/// out wrong.
class TalkProgress extends StatelessWidget {
  const TalkProgress({super.key, required this.runs, required this.conv, required this.now});
  final List<TalkRun> runs;
  final Conversations conv;
  final DateTime now;

  static String _pct(int a, int b) => b == 0 ? '–' : '${(100 * a / b).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = dayOf(now);
    final weekStart = dayPlus(today, -6);
    final thisWeek = [for (final r in runs) if (!r.at.isBefore(weekStart)) r];
    final weekChoices = thisWeek.fold(0, (a, r) => a + r.choices.length);
    final weekFirst = thisWeek.fold(0, (a, r) => a + r.firstTime);
    final weekSpoken = thisWeek.fold(0, (a, r) => a + r.spokenTurns.length);
    final weekWell = thisWeek.fold(0, (a, r) => a + r.saidWell);
    final tried = {for (final r in runs) r.scene};

    // Said well, as a share of replies said, for each of the last 8 weeks.
    const weeks = 8;
    final said = List.filled(weeks, 0), well = List.filled(weeks, 0);
    final starts = [for (var i = 0; i < weeks; i++) dayPlus(today, -6 - 7 * (weeks - 1 - i))];
    for (final r in runs) {
      for (var i = weeks - 1; i >= 0; i--) {
        if (!r.at.isBefore(starts[i])) {
          said[i] += r.spokenTurns.length;
          well[i] += r.saidWell;
          break;
        }
      }
    }

    // Each scene you've tried: its last go, due ones first.
    final scenes = [
      for (final s in conv.scenes)
        if (tried.contains(s.id)) (s, runsOf(runs, s.id).last),
    ]..sort((a, b) => reviewDue(a.$2).compareTo(reviewDue(b.$2)));

    // Sound slips over the last 30 days.
    final slips = <String, int>{};
    for (final r in runs) {
      if (r.at.isBefore(dayPlus(today, -29))) continue;
      r.slipCounts.forEach((k, v) => slips[k] = (slips[k] ?? 0) + v);
    }
    final topSlips = (slips.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

    Widget tile(String label, String value) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.bodySmall, maxLines: 2),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleLarge),
              ]),
            ),
          ),
        );

    final topShare = [for (var i = 0; i < weeks; i++) said[i] == 0 ? 0.0 : well[i] / said[i]].fold<double>(0, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          tile('Scenes this week', '${thisWeek.length}'),
          const SizedBox(width: 8),
          tile('Right first time', _pct(weekFirst, weekChoices)),
          const SizedBox(width: 8),
          tile('Said well', _pct(weekWell, weekSpoken)),
        ]),
        const SizedBox(height: 8),
        Text('${tried.length} of ${conv.scenes.length} scenes tried', style: theme.textTheme.bodySmall),
        if (said.any((n) => n > 0)) ...[
          const SizedBox(height: 14),
          Text('Replies said well, by week', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SizedBox(
            height: 96,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < weeks; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (said[i] > 0)
                        Text(_pct(well[i], said[i]), style: theme.textTheme.labelSmall, maxLines: 1, softWrap: false),
                      const SizedBox(height: 2),
                      Container(
                        height: said[i] == 0 || topShare == 0 ? 0 : max(2, 56 * (well[i] / said[i]) / topShare),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${starts[i].day}/${starts[i].month}', style: theme.textTheme.labelSmall, maxLines: 1),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Text('Scenes', style: theme.textTheme.labelLarge),
        for (final (s, last) in scenes)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Tooltip(
              message: markLabel(last.mark),
              child: Icon(Icons.circle, size: 14, color: markColor(last.mark, scheme)),
            ),
            title: Text(s.title),
            subtitle: Text([
              if (last.choices.isNotEmpty) '${last.firstTime}/${last.choices.length} right',
              if (last.spokenTurns.isNotEmpty) '${last.saidWell}/${last.spokenTurns.length} said well',
            ].join(' · ')),
            trailing: Text(_due(reviewDue(last), today), style: theme.textTheme.bodySmall),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(scene: s))),
          ),
        if (topSlips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Sounds that came out wrong most', style: theme.textTheme.labelLarge),
          Text('Last 30 days, from what the recogniser heard', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in topSlips) Chip(label: Text('${slipText(e.key)}${e.value > 1 ? ' ×${e.value}' : ''}')),
          ]),
        ],
      ],
    );
  }

  static String _due(DateTime due, DateTime today) {
    final days = dayOf(due).difference(today).inDays;
    if (days <= 0) return 'Review due';
    return days == 1 ? 'Again tomorrow' : 'Again in $days days';
  }
}
