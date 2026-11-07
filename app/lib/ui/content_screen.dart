import 'package:flutter/material.dart';

import 'common.dart';

/// Rough guide to what each HSK level is for, in plain words.
String levelBlurb(int level) => switch (level) {
      1 => 'First words: greetings, numbers, people',
      2 => 'Everyday basics: shopping, time, getting around',
      3 => 'Daily life: work, school, feelings',
      4 => 'Talking about plans, opinions and experiences',
      5 => 'News, longer conversations, abstract ideas',
      6 => 'Fluent everyday reading and talk',
      _ => 'Advanced and university-level words',
    };

/// Settings → Levels and content: which parts of the library show up.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final library = scope.library;
    final store = scope.store;
    final theme = Theme.of(context);
    final perLevel = <int, int>{};
    var phrases = 0, sentences = 0;
    for (final e in library.entries) {
      if (e.isSentence) {
        sentences++;
      } else if (e.curated || e.hsk == null) {
        phrases++;
      } else {
        perLevel[e.hsk!] = (perLevel[e.hsk!] ?? 0) + 1;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Levels and content')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Turn on a level when you are ready for it. Anything turned off stays out of the '
                'library, word of the day, related words and practice choices. Words you have '
                'starred always stay, whatever their level.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            for (final l in library.levels)
              SwitchListTile(
                title: Text('HSK $l'),
                subtitle: Text('${perLevel[l] ?? 0} words · ${levelBlurb(l)}'),
                value: store.levels.contains(l),
                onChanged: (on) => store.setLevelShown(l, on),
              ),
            SwitchListTile(
              title: const Text('Phrasebook sentences'),
              subtitle: Text('$sentences sentences from native speakers'),
              value: store.showSentences,
              onChanged: store.setShowSentences,
            ),
            ListTile(
              title: const Text('Topic words and phrases'),
              subtitle: Text('$phrases hand-picked for the topics (food, travel, love…), always shown'),
              trailing: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
