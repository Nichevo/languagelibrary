import 'dart:convert';

import 'package:flutter/material.dart';

import '../srs/scheduler.dart';
import '../data/storage.dart';
import 'about_screen.dart';
import 'drill_screen.dart';
import 'common.dart';
import 'content_screen.dart';
import 'practice_screen.dart';

/// The Practice tab: pick what to study, plus settings and credits.
class PracticeHome extends StatelessWidget {
  const PracticeHome({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          const sched = Scheduler();
          int due(String? list) => store
              .idsIn(list)
              .expand((id) => Direction.values.map((d) => store.card(id, d)))
              .where((c) => sched.isDue(c, now))
              .length;

          Widget listTile(String title, String? list) {
            final count = store.idsIn(list).length;
            final d = due(list);
            return ListTile(
              leading: const Icon(Icons.style),
              title: Text(title),
              subtitle: Text('$count words · $d cards due'),
              trailing: const Icon(Icons.chevron_right),
              enabled: count > 0,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => switch (store.practiceMode) {
                  'listen' => DrillScreen(drill: Drill.listen, list: list),
                  'type' => DrillScreen(drill: Drill.type, list: list),
                  _ => PracticeScreen(list: list, includeNotDue: d == 0),
                },
              )),
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cards', icon: Icon(Icons.style_outlined), label: Text('Cards')),
                    ButtonSegment(value: 'listen', icon: Icon(Icons.checklist), label: Text('Choose')),
                    ButtonSegment(value: 'type', icon: Icon(Icons.keyboard), label: Text('Type')),
                  ],
                  selected: {store.practiceMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => store.setPracticeMode(s.single),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(switch (store.practiceMode) {
                  'listen' => 'Pick the right answer from four. It doesn\'t change your flashcard schedule.',
                  'type' => 'See a word and type its pinyin. It doesn\'t change your flashcard schedule.',
                  _ => 'Each word has two cards: Chinese → English and English → Chinese.',
                }),
              ),
              if (store.practiceMode == 'listen')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: Choice.fromSetting(store.choiceKind) == null ? 'mix' : store.choiceKind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder(), isDense: true),
                    onChanged: (v) => store.setChoiceKind(v!),
                    items: [
                      for (final c in Choice.pickable) DropdownMenuItem(value: c.name, child: Text(c.label)),
                      const DropdownMenuItem(value: 'mix', child: Text('Mix them up, with scales to put in order')),
                    ],
                  ),
                ),
              listTile('All starred words', null),
              for (final name in store.lists.keys) listTile(name, name),
              const Divider(),
              const ListTile(title: Text('Settings')),
              ListTile(
                title: const Text('Levels and content'),
                subtitle: Text(_contentSummary(store.levels, store.showSentences)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContentScreen())),
              ),
              ListTile(
                title: const Text('Cards per session'),
                subtitle: const Text('Picked at random, cards that are due first'),
                trailing: DropdownButton<int>(
                  value: store.sessionSize,
                  onChanged: (v) => store.setSessionSize(v!),
                  items: [
                    for (final n in const [10, 20, 30, 50, 100]) DropdownMenuItem(value: n, child: Text('$n')),
                    if (!const [0, 10, 20, 30, 50, 100].contains(store.sessionSize))
                      DropdownMenuItem(value: store.sessionSize, child: Text('${store.sessionSize}')),
                    const DropdownMenuItem(value: 0, child: Text('All')),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Mix in related words'),
                subtitle: const Text('About one in five cards is a word related to one you are practising'),
                value: store.mixRelated,
                onChanged: store.setMixRelated,
              ),
              ListTile(
                title: const Text('Chinese side of the card shows'),
                subtitle: store.cardFront.startsWith('mix') ? const Text('Changes from card to card') : null,
                trailing: DropdownButton<String>(
                  value: store.cardFront,
                  onChanged: (v) => store.setCardFront(v!),
                  items: const [
                    DropdownMenuItem(value: 'hanzi', child: Text('Hanzi')),
                    DropdownMenuItem(value: 'pinyin', child: Text('Pinyin')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio only')),
                    DropdownMenuItem(value: 'mix', child: Text('Mix hanzi + pinyin')),
                    DropdownMenuItem(value: 'mixAll', child: Text('Mix all three')),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Flashcard voice'),
                subtitle: Text(store.femaleVoice ? 'Female' : 'Male'),
                value: store.femaleVoice,
                onChanged: store.setFemaleVoice,
              ),
              SwitchListTile(
                title: const Text('Slow audio (0.75×)'),
                value: store.slowAudio,
                onChanged: store.setSlowAudio,
              ),
              SwitchListTile(
                title: const Text('Colour characters by tone'),
                subtitle: const Text('Pinyin is always coloured'),
                value: store.toneHanzi,
                onChanged: store.setToneHanzi,
              ),
              SwitchListTile(
                title: const Text('Daily reminder'),
                subtitle: Text(store.reminderOn
                    ? 'At ${_time(context, store.reminderMinutes)} on days when cards are due'
                    : 'Off'),
                value: store.reminderOn,
                onChanged: (on) async {
                  if (on && !await scope.device.allowNotifications()) {
                    if (context.mounted) {
                      _say(context, 'Notifications are turned off for this app in your phone\'s settings.');
                    }
                    return;
                  }
                  await store.setReminder(on: on);
                },
              ),
              if (store.reminderOn)
                ListTile(
                  title: const Text('Reminder time'),
                  trailing: Text(_time(context, store.reminderMinutes)),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: store.reminderMinutes ~/ 60, minute: store.reminderMinutes % 60),
                    );
                    if (t != null) await store.setReminder(on: true, minutes: t.hour * 60 + t.minute);
                  },
                ),
              const Divider(),
              const ListTile(title: Text('Your progress')),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Back up to a file'),
                subtitle: const Text('Stars, lists, Easy / OK / Hard scores and flashcard progress'),
                onTap: () async {
                  final now = DateTime.now();
                  final name = 'language-library-backup-${now.toIso8601String().substring(0, 10)}.json';
                  final ok = await scope.device.saveFile(name, utf8.encode(store.exportBackup(now)));
                  if (context.mounted && ok) _say(context, 'Saved $name');
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore from a file'),
                subtitle: const Text('Replaces what is on this phone'),
                onTap: () => _restore(context),
              ),
              const Divider(),
              const StorageSection(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About, sources and credits'),
                subtitle: store.reported.isEmpty ? null : Text('${store.reported.length} reported problems'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _time(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  static void _say(BuildContext context, String text) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _restore(BuildContext context) async {
    final scope = AppScope.of(context);
    final bytes = await scope.device.openFile();
    if (bytes == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text('Your stars, lists, scores and flashcard progress on this phone will be replaced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await scope.store.importBackup(utf8.decode(bytes, allowMalformed: true));
      if (context.mounted) _say(context, 'Restored ${scope.store.starred.length} starred ${scope.store.starred.length == 1 ? 'word' : 'words'}.');
    } on FormatException catch (e) {
      if (context.mounted) _say(context, e.message);
    }
  }
}

/// How much space each part of the library takes on the phone.
class StorageSection extends StatefulWidget {
  const StorageSection({super.key});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  Future<List<StoragePart>>? _parts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parts ??= libraryStorage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<StoragePart>>(
      future: _parts,
      builder: (context, snap) {
        final parts = snap.data == null
            ? null
            : ([...snap.data!, progressStorage(AppScope.of(context).store)]..sort((a, b) => b.bytes.compareTo(a.bytes)));
        final total = parts?.fold<int>(0, (n, p) => n + p.bytes) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Space on this phone'),
              subtitle: Text(parts == null
                  ? (snap.hasError ? 'Could not measure' : 'Measuring...')
                  : '${formatBytes(total)} of library data and progress. The app itself takes more on top.'),
            ),
            for (final p in parts ?? const <StoragePart>[])
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(p.label, style: theme.textTheme.bodyLarge)),
                        Text(formatBytes(p.bytes), style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: total == 0 ? 0 : p.bytes / total),
                    const SizedBox(height: 2),
                    Text(p.detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "HSK 1–3 and the phrasebook", for the Settings row.
String _contentSummary(Set<int> levels, bool sentences) {
  final l = levels.toList()..sort();
  final parts = <String>[];
  for (var i = 0; i < l.length; i++) {
    var j = i;
    while (j + 1 < l.length && l[j + 1] == l[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${l[i]}' : '${l[i]}–${l[j]}');
    i = j;
  }
  final hsk = parts.isEmpty ? 'No HSK levels' : 'HSK ${parts.join(', ')}';
  return sentences ? '$hsk and the phrasebook' : hsk;
}
