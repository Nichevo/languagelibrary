import 'dart:convert';

import 'package:flutter/material.dart';

import '../srs/scheduler.dart';
import 'about_screen.dart';
import 'common.dart';
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
                builder: (_) => PracticeScreen(list: list, includeNotDue: d == 0),
              )),
            );
          }

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Each word has two cards: Chinese → English and English → Chinese.'),
              ),
              listTile('All starred words', null),
              for (final name in store.lists.keys) listTile(name, name),
              const Divider(),
              const ListTile(title: Text('Settings')),
              ListTile(
                title: const Text('Chinese side of the card shows'),
                trailing: DropdownButton<String>(
                  value: store.cardFront,
                  onChanged: (v) => store.setCardFront(v!),
                  items: const [
                    DropdownMenuItem(value: 'hanzi', child: Text('Hanzi')),
                    DropdownMenuItem(value: 'pinyin', child: Text('Pinyin')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio only')),
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
