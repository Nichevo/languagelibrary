import 'package:flutter/material.dart';

import '../data/conversations.dart';
import '../data/talk.dart';
import '../models/entry.dart';
import '../speech/heard.dart';
import 'common.dart';
import 'say_it_screen.dart';

/// The colour of a scene's mark.
Color markColor(TalkMark m, ColorScheme scheme) => switch (m) {
      TalkMark.good => Colors.green.shade600,
      TalkMark.middling => Colors.amber.shade700,
      TalkMark.poor => scheme.error,
    };

String markLabel(TalkMark m) => switch (m) {
      TalkMark.good => 'Went well',
      TalkMark.middling => 'Getting there',
      TalkMark.poor => 'Needs another go',
    };

/// What came out wrong in [check], as "忙>慢" (or "忙>" when nothing was heard for it).
List<String> slipsOf(WordCheck check) => [
      for (final s in check.syllables)
        if (s.heard != Heard.right && s.syllable.hanzi != null) '${s.syllable.hanzi}>${s.char ?? ''}',
    ];

/// "忙 heard as 慢", or "忙 not heard".
String slipText(String slip) {
  final i = slip.indexOf('>');
  final want = slip.substring(0, i), got = slip.substring(i + 1);
  return got.isEmpty ? '$want not heard' : '$want heard as $got';
}

String _pct(double x) => '${(x * 100).round()}%';

String _time(int seconds) => seconds < 60 ? '$seconds s' : '${seconds ~/ 60} min ${seconds % 60} s';

/// The library words you slipped on in [run], each once.
List<Entry> wordsToWorkOn(TalkRun run, Conversations conv, Map<String, Entry> library) {
  final out = <String, Entry>{};
  for (final t in run.turns) {
    final slipped = {for (final s in t.slips) s.split('>').first};
    if (slipped.isEmpty) continue;
    for (final (hanzi, id) in conv.words[t.picked] ?? const <(String, String?)>[]) {
      if (id == null || !hanzi.split('').any(slipped.contains)) continue;
      if (library[id] case final e?) out[id] = e;
    }
  }
  return out.values.toList();
}

/// The review at the end of a conversation, or when you stop one early.
class TalkReview extends StatelessWidget {
  const TalkReview({super.key, required this.run, required this.earlier, required this.onAgain});
  final TalkRun run;

  /// Earlier goes at the same scene, oldest first.
  final List<TalkRun> earlier;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final conv = scope.library.conversations;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final choices = run.choices.length;
    final spoken = run.spokenTurns.length;
    final last = earlier.isEmpty ? null : earlier.last;
    final work = wordsToWorkOn(run, conv, scope.library.byId);
    final slips = run.slipCounts;
    final history = [...earlier, run];
    final shown = history.length > 5 ? history.sublist(history.length - 5) : history;

    Widget tile(String big, String small) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(big, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              Text(small, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    final missed = [for (final t in run.choices) if (!t.firstTime) t];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.circle, size: 14, color: markColor(run.mark, scheme)),
              const SizedBox(width: 8),
              Expanded(child: Text('How it went', style: theme.textTheme.titleLarge)),
              Text(run.finished ? '${run.turns.length} turns' : 'Stopped after ${run.turns.length}',
                  style: theme.textTheme.labelMedium),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: [
                tile(choices == 0 ? '–' : '${run.firstTime} / $choices', 'right reply first time'),
                if (!run.chooseOnly) tile(spoken == 0 ? '–' : '${run.saidWell} / $spoken', 'said well'),
                if (!run.chooseOnly)
                  tile(run.triesPerReply == null ? '–' : run.triesPerReply!.toStringAsFixed(1), 'tries per reply'),
                tile(_time(run.seconds), 'time in the scene'),
                if (!run.chooseOnly)
                  tile(run.heardShare == null ? '–' : _pct(run.heardShare!), 'characters heard right'),
                tile('${run.englishPeeks}', run.englishPeeks == 1 ? 'peek at the English' : 'peeks at the English'),
              ],
            ),
            const SizedBox(height: 12),
            _Note(
              good: missed.isEmpty,
              title: choices == 0
                  ? 'Understanding'
                  : 'Understanding: ${run.firstTime == choices ? 'strong' : run.firstTime * 2 >= choices ? 'getting there' : 'needs another go'}',
              text: choices == 0
                  ? 'You started the conversation; there was nothing to choose.'
                  : missed.isEmpty
                      ? 'You picked a right reply first time at every turn.'
                      : 'You picked a reply that didn\'t fit ${missed.length == 1 ? 'once' : '${missed.length} times'}. '
                          'Those are marked below.',
            ),
            if (!run.chooseOnly && spoken > 0) ...[
              const SizedBox(height: 8),
              _Note(
                good: run.saidWell == spoken,
                title: 'Speaking: ${run.saidWell == spoken ? 'strong' : run.saidWell * 2 >= spoken ? 'getting there' : 'needs practice'}',
                text: slips.isEmpty
                    ? 'Every reply you said was heard right, in ${run.tries} ${run.tries == 1 ? 'try' : 'tries'}.'
                    : 'Most heard-wrong: ${slips.entries.take(3).map((e) => '${slipText(e.key)}'
                        '${e.value > 1 ? ' (${e.value} times)' : ''}').join(', ')}.',
              ),
            ],
            if (!run.chooseOnly && spoken == 0 && run.turns.isNotEmpty) ...[
              const SizedBox(height: 8),
              const _Note(good: false, title: 'Speaking', text: 'You didn\'t say any replies this time.'),
            ],
            if (shown.length > 1) ...[
              const SizedBox(height: 14),
              Text('THIS SCENE, LAST ${shown.length} GOES', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 6),
              _Bars(runs: shown),
            ],
            if (last != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Compared with last time')),
                Text(_compare(last, run), style: theme.textTheme.titleSmall),
              ]),
            ],
            const SizedBox(height: 14),
            Text('TURN BY TURN', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
            for (final t in run.turns) _TurnRow(turn: t, entry: conv.entries[t.picked], chooseOnly: run.chooseOnly),
            if (work.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('WORDS TO WORK ON', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in work)
                  ActionChip(
                    label: Text(e.simplified),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SayItScreen(entries: [e]))),
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              if (work.isNotEmpty)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SayItScreen(entries: work))),
                  child: const Text('Practise these'),
                ),
              const Spacer(),
              OutlinedButton(onPressed: onAgain, child: const Text('Again')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ]),
          ],
        ),
      ),
    );
  }

  static String _compare(TalkRun last, TalkRun now) {
    final parts = <String>[];
    final right = now.firstTime - last.firstTime;
    if (right != 0) parts.add('${right > 0 ? '+' : ''}$right right first time');
    if (!now.chooseOnly && !last.chooseOnly) {
      final said = now.saidWell - last.saidWell;
      if (said != 0) parts.add('${said > 0 ? '+' : ''}$said said well');
    }
    return parts.isEmpty ? 'the same' : parts.join(', ');
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.good, required this.title, required this.text});
  final bool good;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = good ? Colors.green.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.16);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(text, style: theme.textTheme.bodyMedium),
      ]),
    );
  }
}

/// One bar per go: how much of the scene went right (understanding, and
/// speaking where you spoke). The last bar is this go.
class _Bars extends StatelessWidget {
  const _Bars({required this.runs});
  final List<TalkRun> runs;

  static double score(TalkRun r) {
    final n = r.choices.length;
    final u = n == 0 ? 1.0 : r.firstTime / n;
    final s = r.spokenTurns.isEmpty ? null : r.saidWell / r.spokenTurns.length;
    return s == null ? u : (u + s) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < runs.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: 0.12 + 0.88 * score(runs[i]),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: markColor(runs[i].mark, scheme).withValues(alpha: i == runs.length - 1 ? 1 : 0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TurnRow extends StatelessWidget {
  const _TurnRow({required this.turn, required this.entry, required this.chooseOnly});
  final TalkTurn turn;
  final Entry? entry;
  final bool chooseOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final good = turn.firstTime && (chooseOnly || !turn.spoken || turn.saidWell);
    final notes = <String>[
      if (!turn.choice) 'Your opening line',
      if (turn.choice) turn.firstTime ? 'Picked first time' : 'Picked after ${turn.wrongPicks} wrong',
      if (!chooseOnly)
        !turn.spoken
            ? 'not said'
            : turn.saidWell
                ? 'said well on try ${turn.tries}'
                : 'not heard right after ${turn.tries} ${turn.tries == 1 ? 'try' : 'tries'}',
      for (final s in turn.slips) slipText(s),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(turn.firstTime ? Icons.check : Icons.close,
            size: 18, color: !turn.firstTime ? scheme.error : good ? Colors.green.shade600 : Colors.amber.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (entry != null) HanziText(entry!, style: theme.textTheme.titleMedium),
            Text(notes.join(' · '), style: theme.textTheme.bodySmall),
          ]),
        ),
        if (entry != null)
          IconButton(
            tooltip: 'Play',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () {
              final scope = AppScope.of(context);
              scope.speaker.play(entry!, female: false).catchError((_) {});
            },
          ),
      ]),
    );
  }
}
