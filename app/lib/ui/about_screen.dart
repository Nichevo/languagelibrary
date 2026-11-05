import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'entry_screen.dart';

/// Where every piece of data comes from, the licenses, and reported problems.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const sources = [
    (
      'HSK word lists',
      'complete-hsk-vocabulary, MIT License',
      'https://github.com/drkameleon/complete-hsk-vocabulary',
      'Which words are in the starter set, and their HSK level.',
    ),
    (
      'CC-CEDICT',
      'MDBG, Creative Commons Attribution-ShareAlike 4.0',
      'https://www.mdbg.net/chinese/dictionary?page=cc-cedict',
      'Every meaning, pinyin and measure word shown in the app. Our build keeps only words '
          'where CC-CEDICT and the HSK list agree.',
    ),
    (
      'Tatoeba',
      'Creative Commons Attribution 2.0 France (CC BY 2.0 FR)',
      'https://tatoeba.org',
      'Phrasebook and example sentences, in Chinese and English. Only sentences added by people '
          'who list Mandarin as their native language are used, and each one shows its Tatoeba '
          'number and who wrote it. Licence: https://creativecommons.org/licenses/by/2.0/fr/',
    ),
    (
      'Voices',
      'Google Cloud Text-to-Speech',
      'https://cloud.google.com/text-to-speech',
      'Female and male recordings, made once and stored in the app. Each clip was checked '
          'with Google Speech-to-Text.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${scope.library.entries.length} words and phrases', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Topic tags (Food, Travel and so on) are added by our build script to help '
                'filtering; they are not part of the dictionaries.'),
            const SizedBox(height: 16),
            Text('Sources', style: theme.textTheme.titleMedium),
            for (final (name, license, url, what) in sources)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      Text(license, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(what),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => Clipboard.setData(ClipboardData(text: url)),
                        child: Text('$url  (tap to copy)',
                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => showLicensePage(context: context, applicationName: 'Language Library'),
              child: const Text('Full license texts'),
            ),
            const SizedBox(height: 24),
            Text('Reported problems', style: theme.textTheme.titleMedium),
            if (store.reported.isEmpty)
              const Text('None yet. Use "Report a problem" on any word.')
            else ...[
              for (final MapEntry(key: id, value: note) in store.reported.entries)
                if (scope.library.byId[id] case final e?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${e.simplified}  ${e.pinyin}'),
                    subtitle: Text(note),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(e))),
                  ),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy list to share'),
                onPressed: () => Clipboard.setData(ClipboardData(
                  text: [
                    for (final MapEntry(key: id, value: note) in store.reported.entries)
                      if (scope.library.byId[id] case final e?) '${e.simplified} (${e.pinyin}) [$id]: $note',
                  ].join('\n'),
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
