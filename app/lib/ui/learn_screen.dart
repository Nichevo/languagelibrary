import 'package:flutter/material.dart';

import 'common.dart';
import 'families_screen.dart';
import 'patterns_screen.dart';
import 'scales_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';

/// A way of learning on the Learn tab: a card that opens its own page.
class LearnSection {
  const LearnSection(this.title, this.subtitle, this.icon, this.view);
  final String title, subtitle;
  final IconData icon;

  /// The section's content for a search: the query and the ids it matched
  /// (null when there is no search).
  final Widget Function(String query, Set<String>? matching) view;
}

final learnSections = <LearnSection>[
  LearnSection('Families', 'One character, many words', Icons.account_tree_outlined,
      (q, m) => FamiliesView(query: q, matching: m)),
  LearnSection('Patterns', 'How Chinese sentences are built', Icons.view_week_outlined,
      (q, m) => PatternsView(matching: m)),
  LearnSection('Tricky sounds', 'Words that differ only by tone', Icons.hearing, (q, m) => SoundsView(matching: m)),
  LearnSection('Pairs & scales', 'Opposites and words in order', Icons.swap_vert, (q, m) => ScalesView(matching: m)),
];

/// The Learn tab: the ways in, beyond single words.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Learn'), actions: const [SettingsButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('Ways to see how words fit together.', style: theme.textTheme.bodyMedium),
          ),
          for (final s in learnSections)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(s.icon, color: theme.colorScheme.primary),
                title: Text(s.title),
                subtitle: Text(s.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LearnPage(s))),
              ),
            ),
        ],
      ),
    );
  }
}

/// One Learn section with a search box over it.
class LearnPage extends StatefulWidget {
  const LearnPage(this.section, {super.key});
  final LearnSection section;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) {
        final q = _query.trim();
        final matching = q.isEmpty ? null : {for (final e in scope.library.search(q, shown: scope.store.shows)) e.id};
        return Scaffold(
          appBar: AppBar(title: Text(widget.section.title)),
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
              Expanded(child: widget.section.view(q, matching)),
            ],
          ),
        );
      },
    );
  }
}
