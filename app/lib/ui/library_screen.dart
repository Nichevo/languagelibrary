import 'package:flutter/material.dart';

import '../data/daily.dart';
import '../data/library.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'settings_screen.dart';
import 'wide.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  String? _topic;

  /// The word shown beside the list on a wide screen.
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(listenable: scope.store, builder: (context, _) => _build(context, scope));
  }

  Widget _build(BuildContext context, AppScope scope) {
    final library = scope.library;
    final store = scope.store;
    final results = library.search(_query, topic: _topic, shown: store.shows);
    final list = Scaffold(
      appBar: AppBar(title: const Text('Library'), actions: const [SettingsButton()]),
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
                if (store.showSentences) _chip('Sentences', Library.sentencesFilter),
                for (final t in Library.topics) _chip(topicLabel(t), t),
              ],
            ),
          ),
          ...[
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
    if (!isWide(context)) return list;

    // iPad and other big screens: the list on the left, the word on the right.
    final shownId = _selected ??
        wordOfTheDay(library, DateTime.now(), shown: store.shows)?.id ??
        (results.isEmpty ? null : results.first.id);
    final shown = shownId == null ? null : library.byId[shownId];
    return Row(
      children: [
        SizedBox(
          width: 400,
          child: EntryPicker(selected: shown?.id, onPick: (e) => setState(() => _selected = e.id), child: list),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: shown == null
              ? const Scaffold(body: Center(child: Text('Pick a word on the left')))
              : EntryScreen(shown, key: ValueKey(shown.id)),
        ),
      ],
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
          onTap: () {
            final picker = EntryPicker.maybeOf(context);
            if (picker != null) return picker.onPick(entry);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(entry)));
          },
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
