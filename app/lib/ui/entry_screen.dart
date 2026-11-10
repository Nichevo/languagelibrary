import 'package:flutter/material.dart';

import '../data/user_store.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_tile.dart';
import 'scales_screen.dart';
import 'sounds_screen.dart';
import '../data/sounds.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen(this.entry, {super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final b = theme.brightness;
    final studio = scope.speaker.hasStudioAudio(entry);
    final related = [
      for (final r in entry.related)
        if (scope.library.byId[r.id] case final e?) (r, e),
    ];

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(actions: [StarButton(entry), _ListsButton(entry)]),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Center(
              child: HanziText(entry,
                  textAlign: TextAlign.center,
                  style: (entry.isSentence ? theme.textTheme.headlineLarge : theme.textTheme.displayLarge)
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Center(
              child: PinyinText(entry,
                  textAlign: TextAlign.center,
                  style: entry.isSentence ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(entry.gloss,
                  textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                [
                  if (entry.hsk != null) 'HSK ${entry.hsk}',
                  ...entry.topics.map(topicLabel),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _VoiceButton(entry, female: true)),
                const SizedBox(width: 12),
                Expanded(child: _VoiceButton(entry, female: false)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Slow (0.75×)'),
                Switch(value: store.slowAudio, onChanged: store.setSlowAudio),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Column(
                children: [
                  Text('How hard is this for you?', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SegmentedButton<Difficulty>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: [
                      for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label)),
                    ],
                    selected: {?store.difficulty[entry.id]},
                    onSelectionChanged: (s) => store.setDifficulty(entry.id, s.isEmpty ? null : s.first),
                  ),
                ],
              ),
            ),
            if (!studio)
              Text(
                'No checked recording for this word yet, so it uses your phone\'s Chinese voice.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            section('Pronunciation', [
              for (final s in entry.syllables)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(TextSpan(children: [
                    if (s.hanzi != null) TextSpan(text: '${s.hanzi}  '),
                    TextSpan(
                      text: s.pinyin,
                      style: TextStyle(color: toneColor(s.tone, b), fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: s.pinyin == 'r'
                          ? '  the -r ending'
                          : '  =  ${s.initial.isEmpty ? '' : '${s.initial} + '}${s.finalPart},  ${s.toneName}',
                    ),
                  ])),
                ),
              if (entry.spoken != null) ...[
                const SizedBox(height: 6),
                for (final n in entry.soundNotes)
                  Text(n, style: TextStyle(color: theme.colorScheme.tertiary)),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'So it is said: '),
                  TextSpan(text: entry.spoken, style: const TextStyle(fontWeight: FontWeight.w600)),
                ])),
              ],
              for (final n in entry.notes) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(n),
              ),
            ]),
            section('Meanings', [
              for (final m in entry.meanings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('•  $m'),
                ),
            ]),
            if (entry.examples.isNotEmpty)
              section('Example sentences', [
                for (final x in entry.examples)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Play',
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => scope.speaker.speakText(x.zh, slow: store.slowAudio),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(x.zh, style: theme.textTheme.titleMedium),
                              Text(x.pinyin, style: theme.textTheme.bodySmall),
                              Text(x.en),
                              Text(x.credit.join(' · '),
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Text('Read by your phone\'s Chinese voice.', style: theme.textTheme.bodySmall),
              ]),
            if (entry.classifiers.isNotEmpty)
              section('Measure word', [
                Text(entry.classifiers.map((c) => '${c.hanzi} ${c.pinyin}').join(',  ')),
              ]),
            for (final sc in scope.library.scalesFor(entry)) ScaleCard(sc, entry),
            if (toneSetFor(scope.library, entry) case final ts?)
              section('Same sound, other tones', [
                Text('Tap to hear the ${ts.byTone.length} tones of ${ts.syllable} side by side.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                ToneSetCard(ts, marked: entry),
              ]),
            if (related.isNotEmpty)
              section('Related words and phrases', [
                Text(entry.isSentence ? 'Words in this sentence. Tap one to open it, or star it here.' : 'Tap one to open it, or star it here.',
                    style: theme.textTheme.bodySmall),
                for (final (r, e) in related)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: EntryTile(
                        e,
                        trailingNote: Text(r.why, style: theme.textTheme.bodySmall),
                      ),
                    ),
                  ),
              ]),
            section('Source', [
              Text(entry.sources.toSet().join(' · '), style: theme.textTheme.bodySmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: Icon(store.reported.containsKey(entry.id) ? Icons.flag : Icons.outlined_flag),
                  label: Text(store.reported.containsKey(entry.id)
                      ? 'Reported: ${store.reported[entry.id]}'
                      : 'Report a problem'),
                  onPressed: () => _report(context),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    final store = AppScope.of(context).store;
    final controller = TextEditingController(text: store.reported[entry.id] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Problem with ${entry.simplified}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. audio sounds wrong, odd meaning'),
        ),
        actions: [
          if (store.reported.containsKey(entry.id))
            TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    if (result.trim().isEmpty) {
      await store.clearReport(entry.id);
    } else {
      await store.report(entry.id, result.trim());
    }
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton(this.entry, {required this.female});

  final Entry entry;
  final bool female;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.play_arrow),
      label: Text(female ? 'Female voice' : 'Male voice'),
      onPressed: () => scope.speaker.play(entry, female: female, slow: scope.store.slowAudio),
    );
  }
}

/// Put the entry into custom lists such as "This week" or "Restaurant".
class _ListsButton extends StatelessWidget {
  const _ListsButton(this.entry);

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Add to a list',
      icon: const Icon(Icons.playlist_add),
      onPressed: () => showModalBottomSheet(
        context: context,
        builder: (_) => _ListsSheet(entry),
      ),
    );
  }
}

class _ListsSheet extends StatelessWidget {
  const _ListsSheet(this.entry);

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Lists')),
            for (final name in store.lists.keys)
              CheckboxListTile(
                title: Text(name),
                value: store.lists[name]!.contains(entry.id),
                onChanged: (v) => store.setInList(name, entry.id, v ?? false),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New list'),
              onTap: () async {
                final name = await askListName(context);
                if (name != null) {
                  await store.createList(name);
                  await store.setInList(name, entry.id, true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> askListName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New list'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Restaurant'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
      ],
    ),
  );
  return (name == null || name.trim().isEmpty) ? null : name.trim();
}
