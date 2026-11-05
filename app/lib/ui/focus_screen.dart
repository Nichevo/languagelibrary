import 'package:flutter/material.dart';

import '../data/user_store.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'practice_screen.dart';

/// Your starred words, optional custom lists, and what's due to practise.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  String? _list; // null = all starred
  Difficulty? _level; // null = any score

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (_list != null && !store.lists.containsKey(_list)) _list = null;
        final now = DateTime.now();
        const sched = Scheduler();
        final entries = [
          for (final id in store.idsIn(_list).reversed)
            if (scope.library.byId[id] != null && (_level == null || store.difficulty[id] == _level))
              scope.library.byId[id]!,
        ];
        int dueFor(String id) =>
            Direction.values.where((d) => sched.isDue(store.card(id, d), now)).length;
        final dueCards = entries.fold<int>(0, (sum, e) => sum + dueFor(e.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Focus list'),
            actions: [
              if (_list != null)
                IconButton(
                  tooltip: 'Delete this list',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, _list!),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${entries.length} ${entries.length == 1 ? 'word' : 'words'} · $dueCards cards due',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip('All starred', null),
                    for (final name in store.lists.keys) _chip(name, name),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('List'),
                        onPressed: () async {
                          final name = await askListName(context);
                          if (name != null) {
                            await store.createList(name);
                            setState(() => _list = name);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final d in Difficulty.values.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(d.label),
                          selected: _level == d,
                          onSelected: (on) => setState(() => _level = on ? d : null),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _level != null
                                ? 'No words here scored ${_level!.label}. Score a word from its page.'
                                : _list == null
                                ? 'Star words in the Library to add them here.'
                                : 'Add words to "$_list" from a word\'s page.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final due = dueFor(entries[i].id);
                          return EntryTile(
                            entries[i],
                            trailingNote: Text(
                              due > 0 ? '$due due' : _nextDue(store, entries[i].id, now),
                              style: TextStyle(
                                fontSize: 12,
                                color: due > 0 ? Theme.of(context).colorScheme.tertiary : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.style),
                      label: Text(dueCards > 0 ? 'Study $dueCards due cards' : 'Nothing due · study anyway'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PracticeScreen(list: _list, level: _level, includeNotDue: dueCards == 0),
                      )),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _nextDue(UserStore store, String id, DateTime now) {
    final dates = [
      for (final d in Direction.values)
        if (store.card(id, d) != null) store.card(id, d)!.due,
    ];
    if (dates.isEmpty) return '';
    dates.sort();
    final days = dates.first.difference(DateTime(now.year, now.month, now.day)).inDays;
    return days <= 1 ? 'next: tomorrow' : 'next: in $days days';
  }

  Widget _chip(String label, String? list) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _list == list,
          onSelected: (_) => setState(() => _list = list),
        ),
      );

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('The words stay starred; only the list goes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await AppScope.of(context).store.deleteList(name);
    }
  }
}
