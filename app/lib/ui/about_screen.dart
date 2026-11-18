import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'entry_screen.dart';
import 'wide.dart';

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
      'Chinese Dialogues Podcast',
      'Wen-Hua Teng, COERLL, The University of Texas at Austin, Creative Commons Attribution 3.0 (CC BY 3.0)',
      'https://coerll.utexas.edu/coerll/oer/chinese-dialogues-podcast/',
      'The conversations on Practice > Conversations. Lines are copied from the transcripts; which '
          'replies are offered at each turn is worked out by this app, and every scene was checked '
          'in English before it went in.',
    ),
    (
      'WordNet',
      'Copyright Princeton University, WordNet licence',
      'https://wordnet.princeton.edu/',
      'Opposite pairs (大 big / 小 small) are shown only when the two English meanings are '
          'opposites in WordNet.',
    ),
    (
      'Wikipedia: Standard Chinese phonology',
      'Wikipedia contributors, Creative Commons BY-SA 4.0',
      'https://en.wikipedia.org/wiki/Standard_Chinese_phonology',
      'The "how to tell them apart" tips in Practice > Key sounds are our short summaries of the article. '
          'The sound pairs themselves are words from the library.',
    ),
    (
      'Chinese Grammar Wiki',
      'AllSet Learning, Creative Commons BY-NC-SA',
      'https://resources.allsetlearning.com/chinese/grammar/',
      'The word order rules on the Patterns screens are our short summaries of its pages, '
          'and each pattern names the page it comes from. Sentences are split into chunks by this app.',
    ),
    (
      'Voices',
      'Google Cloud Text-to-Speech',
      'https://cloud.google.com/text-to-speech',
      'Female and male recordings, made once and stored in the app. Each clip was checked '
          'with Google Speech-to-Text.',
    ),
    (
      'Say it speech recogniser',
      'sherpa-onnx by the k2-fsa project, Apache License 2.0',
      'https://github.com/k2-fsa/sherpa-onnx',
      'Hears what you said, on this device, using the project\'s small streaming Chinese model '
          '(Zipformer CTC, 2025-04-01). Which syllable came out wrong is worked out by this app from '
          'CC-CEDICT readings. Recordings never leave the device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Readable(child: ListenableBuilder(
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
      )),
    );
  }
}
