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
                title: const Text('Slow audio'),
                value: store.slowAudio,
                onChanged: store.setSlowAudio,
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
}
