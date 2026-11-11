import 'package:flutter/material.dart';

import '../data/families.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'practice_screen.dart';
import 'sounds_screen.dart' show shortMeaning;
import 'wide.dart';

/// The Library's "Families" view: characters you can build on, biggest first.
class FamiliesView extends StatelessWidget {
  const FamiliesView({super.key, this.query = '', this.matching});

  final String query;

  /// Ids of the entries the search matched, or null for no search.
  final Set<String>? matching;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final known = knownIds(store);
    final m = matching;
    final all = families(scope.library, store.shows);
    final shown = m == null
        ? all
        : [for (final f in all) if (query.contains(f.hanzi) || f.heads.any((h) => m.contains(h.id))) f];
    if (shown.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No families match.')));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            'One character, many words. Each family is every word and sentence that uses the character. '
            'Start with a character you know.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final f in shown) _FamilyCard(f, f.all.where((e) => known.contains(e.id)).length),
      ],
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard(this.family, this.known);
  final Family family;
  final int known;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = family;
    final head = f.heads.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FamilyScreen(f.hanzi))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(width: 56, child: HanziText(head, style: theme.textTheme.displaySmall)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${[for (final h in f.heads) h.pinyin].join(' / ')} · ${shortMeaning(head)}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: f.size == 0 ? 0 : known / f.size, minHeight: 5),
                    ),
                    const SizedBox(height: 4),
                    Text('${f.size} entries · $known known', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// One family: the character, what to learn next, then its words and sentences.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen(this.hanzi, {super.key});
  final String hanzi;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final f = familyOf(scope.library, store.shows, hanzi);
        if (f == null) {
          return Scaffold(appBar: AppBar(title: Text('The $hanzi family')), body: Readable(child: const Center(child: Text('No family.'))));
        }
        final known = knownIds(store);
        final k = f.all.where((e) => known.contains(e.id)).length;
        final next = nextToLearn(scope.library, f, store);
        final unstarred = f.words.where((e) => !store.isStarred(e.id)).toList();
        Widget heading(String t, [String? detail]) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: theme.textTheme.titleMedium),
                  if (detail != null) Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            );
        return Scaffold(
          appBar: AppBar(title: Text('The $hanzi family')),
          body: Readable(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              for (final h in f.heads)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: HanziText(h, style: theme.textTheme.headlineMedium),
                    title: PinyinText(h, style: theme.textTheme.titleMedium),
                    subtitle: Text(h.gloss, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () => scope.speaker.play(h, female: store.femaleVoice, slow: store.slowAudio),
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(h))),
                  ),
                ),
              Text('${f.size} entries · $k known', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Practise family'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PracticeScreen(ids: [for (final e in [...f.heads, ...f.words]) e.id]))),
                  ),
                  OutlinedButton.icon(
                    icon: Icon(unstarred.isEmpty ? Icons.star : Icons.star_border),
                    label: Text(unstarred.isEmpty ? 'All words starred' : 'Star ${unstarred.length} words'),
                    onPressed: unstarred.isEmpty
                        ? null
                        : () async {
                            for (final e in unstarred) {
                              await store.toggleStar(e.id);
                            }
                          },
                  ),
                ],
              ),
              if (next != null) ...[
                heading('Next to learn'),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(next.entry))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HanziText(next.entry, style: theme.textTheme.headlineSmall),
                                PinyinText(next.entry, style: theme.textTheme.bodyMedium),
                                Text(next.entry.gloss, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  next.of == 0
                                      ? 'The easiest word here you haven\'t started.'
                                      : 'You know or have starred ${next.known} of its ${next.of} words.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StarButton(next.entry),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (f.words.isNotEmpty) heading('Words with $hanzi (${f.words.length})', 'Easiest first.'),
              for (final e in f.words) EntryTile(e),
              if (f.sentences.isNotEmpty) heading('Sentences with $hanzi (${f.sentences.length})'),
              for (final e in f.sentences) EntryTile(e),
              const SizedBox(height: 16),
              Text('A family is every library entry that uses the character, so it grows as you switch on more levels.',
                  style: theme.textTheme.bodySmall),
            ],
          )),
        );
      },
    );
  }
}

/// On a word page: the families of the characters in it.
class FamiliesCard extends StatelessWidget {
  const FamiliesCard(this.entry, {super.key});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final known = knownIds(store);
    final chars = entry.simplified.runes.map(String.fromCharCode).toSet();
    final fams = [for (final f in families(scope.library, store.shows)) if (chars.contains(f.hanzi)) f]
      ..sort((a, b) => entry.simplified.indexOf(a.hanzi).compareTo(entry.simplified.indexOf(b.hanzi)));
    if (fams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Families', style: theme.textTheme.titleSmall),
          Text('Tap a character to see every word and sentence that uses it.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          for (final f in fams)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Text(f.hanzi, style: theme.textTheme.headlineMedium),
                title: Text([for (final h in f.heads) h.pinyin].join(' / ')),
                subtitle: Text('${f.size} entries · ${f.all.where((e) => known.contains(e.id)).length} known'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FamilyScreen(f.hanzi))),
              ),
            ),
        ],
      ),
    );
  }
}
