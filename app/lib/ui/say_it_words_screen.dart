import 'package:flutter/material.dart';

import '../data/say_it.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'say_it_screen.dart';
import 'wide.dart';

/// Every word tried in Say it, sorted into struggling, getting there and
/// easy by how many tries it usually takes the recogniser to hear it right.
class SayItWordsScreen extends StatelessWidget {
  const SayItWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your words in Say it')),
      body: Readable(
        child: ListenableBuilder(
          listenable: scope.store,
          builder: (context, _) {
            final records = speakRecords(scope.store.speakTries);
            final byLevel = <SpeakLevel?, List<(Entry, SpeakRecord)>>{};
            for (final r in records.values) {
              final e = scope.library.byId[r.id];
              if (e != null) byLevel.putIfAbsent(r.level, () => []).add((e, r));
            }
            for (final list in byLevel.values) {
              // Hardest first: most tries per success, then longest run of misses.
              list.sort((a, b) {
                final c = (b.$2.average ?? 99).compareTo(a.$2.average ?? 99);
                return c != 0 ? c : b.$2.open.compareTo(a.$2.open);
              });
            }
            if (records.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Words you try in Say it show up here, sorted by how many tries they take.',
                      textAlign: TextAlign.center),
                ),
              );
            }
            final struggling = byLevel[SpeakLevel.struggling] ?? const [];
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Each word counts the tries it takes until the recogniser hears it right. '
                    'Struggling: three or more misses in a row, or usually three or more tries. '
                    'Easy: usually right first time, including the last time.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (struggling.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.mic),
                      label: Text('Practise the ${struggling.length} struggling'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SayItScreen(entries: [for (final (e, _) in struggling) e]))),
                    ),
                  ),
                for (final level in [SpeakLevel.struggling, SpeakLevel.gettingThere, SpeakLevel.easy, null])
                  if (byLevel[level] case final list? when list.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('${level?.label ?? 'Not enough tries yet'} (${list.length})',
                          style: theme.textTheme.titleMedium),
                    ),
                    for (final (e, r) in list)
                      ListTile(
                        title: Text('${e.simplified}  ${e.pinyin}'),
                        subtitle: Text('${e.gloss}\n${describeRecord(r)}'),
                        isThreeLine: true,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(e))),
                        trailing: IconButton(
                          tooltip: 'Say it',
                          icon: const Icon(Icons.mic_none),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => SayItScreen(entries: [e]))),
                        ),
                      ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Usually 2.5 tries · right 4 times · 2 misses since" for one word.
String describeRecord(SpeakRecord r) {
  final avg = r.average;
  return [
    if (avg != null) 'Usually ${avg == avg.roundToDouble() ? avg.toInt() : avg.toStringAsFixed(1)} ${avg == 1 ? 'try' : 'tries'}',
    if (r.successes > 0) 'right ${r.successes == 1 ? 'once' : '${r.successes} times'}',
    if (r.successes == 0) '${r.open} ${r.open == 1 ? 'try' : 'tries'}, not right yet'
    else if (r.open > 0) '${r.open} ${r.open == 1 ? 'miss' : 'misses'} since',
  ].join(' · ');
}
