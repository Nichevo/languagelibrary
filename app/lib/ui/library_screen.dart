import 'package:flutter/material.dart';

import '../data/library.dart';
import 'common.dart';
import 'entry_tile.dart';

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
    final library = AppScope.of(context).library;
    final results = library.search(_query, topic: _topic);
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
                for (final t in Library.topics) _chip(topicLabel(t), t),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${results.length} entries', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => EntryTile(results[i]),
            ),
          ),
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
