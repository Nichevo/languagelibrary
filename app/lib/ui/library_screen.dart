import 'package:flutter/material.dart';

import '../data/daily.dart';
import '../data/library.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'scales_screen.dart';
import 'sounds_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(listenable: scope.store, builder: (context, _) => _build(context, scope));
  }

  Widget _build(BuildContext context, AppScope scope) {
    final library = scope.library;
    final store = scope.store;
    final scales = _topic == Library.scalesFilter;
    final sounds = _topic == Library.soundsFilter;
    final results = library.search(_query, topic: scales || sounds ? null : _topic, shown: store.shows);
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search English, pinyin or 汉字',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', null),
                _chip('Pairs & scales', Library.scalesFilter),
                _chip('Tricky sounds', Library.soundsFilter),
                if (store.showSentences) _chip('Sentences', Library.sentencesFilter),
                for (final t in Library.topics) _chip(topicLabel(t), t),
              ],
            ),
          ),
          if (scales)
            Expanded(child: ScalesView(matching: _query.trim().isEmpty ? null : {for (final e in results) e.id}))
          else if (sounds)
            Expanded(child: SoundsView(matching: _query.trim().isEmpty ? null : {for (final e in results) e.id}))
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${results.length} entries', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                final today = _query.isEmpty && _topic == null ? wordOfTheDay(library, DateTime.now(), shown: store.shows) : null;
                final extra = today == null ? 0 : 1;
                return ListView.separated(
                  itemCount: results.length + extra,
                  separatorBuilder: (_, i) => i < extra ? const SizedBox(height: 4) : const Divider(height: 1),
                  itemBuilder: (_, i) => i < extra ? _WordOfTheDay(today!) : EntryTile(results[i - extra]),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String? topic) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _topic == topic,
          onSelected: (_) => setState(() => _topic = topic),
        ),
      );
}

class _WordOfTheDay extends StatelessWidget {
  const _WordOfTheDay(this.entry);

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(entry))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                HanziText(entry, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Word of the day', style: theme.textTheme.labelSmall),
                      PinyinText(entry, style: theme.textTheme.titleSmall),
                      Text(entry.gloss, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                StarButton(entry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
