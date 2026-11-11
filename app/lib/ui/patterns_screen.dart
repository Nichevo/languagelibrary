import 'dart:math';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'wide.dart';

/// Shown on pattern screens: the rules are summarised from Chinese Grammar Wiki,
/// the sentences are from the phrasebook, and the chunks are ours.
const patternsSourceNote = 'Rules summarised from Chinese Grammar Wiki (AllSet Learning, CC BY-NC-SA). '
    'Sentences from Tatoeba. How each sentence is split into chunks is ours.';

/// What each chunk role is called and its colour, so the same job has the same
/// colour in English and Chinese.
const roleLabels = {
  'who': 'who',
  'when': 'when',
  'where': 'where',
  'position': 'in / on',
  'action': 'doing',
  'thing': 'what',
  'question': 'asking',
  'describe': 'describing',
  'link': 'link',
  'count': 'how many',
  'now': 'right now',
  'other': '',
};

Color roleColor(String role, Brightness b) {
  final dark = b == Brightness.dark;
  const light = {
    'who': Color(0xFFDCE8FB),
    'when': Color(0xFFFFF0C2),
    'where': Color(0xFFFFDDC4),
    'position': Color(0xFFFFC9A8),
    'action': Color(0xFFD4F0D6),
    'thing': Color(0xFFE9DDFB),
    'question': Color(0xFFFBD9EA),
    'describe': Color(0xFFD5F2F0),
    'link': Color(0xFFE6E6E6),
    'count': Color(0xFFF3E6C8),
    'now': Color(0xFFC8EBC0),
  };
  const night = {
    'who': Color(0xFF2B3D5C),
    'when': Color(0xFF55471A),
    'where': Color(0xFF5C3A22),
    'position': Color(0xFF6B3A1E),
    'action': Color(0xFF244D2A),
    'thing': Color(0xFF43355E),
    'question': Color(0xFF5C2E45),
    'describe': Color(0xFF1F4B48),
    'link': Color(0xFF3A3A3A),
    'count': Color(0xFF4F4426),
    'now': Color(0xFF2F5A26),
  };
  return (dark ? night : light)[role] ?? (dark ? const Color(0xFF34343A) : const Color(0xFFEEEDF4));
}

class _ChunkBox extends StatelessWidget {
  const _ChunkBox(this.chunk, {this.pinyin, this.big = false});
  final Chunk chunk;
  final String? pinyin;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = roleLabels[chunk.role] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: roleColor(chunk.role, theme.brightness), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chunk.text, style: big ? theme.textTheme.titleLarge : theme.textTheme.titleMedium),
          if (pinyin != null && pinyin!.isNotEmpty) Text(pinyin!, style: theme.textTheme.bodySmall),
          if (label.isNotEmpty)
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// The Library's "Patterns" view.
class PatternsView extends StatelessWidget {
  const PatternsView({super.key, this.matching});

  /// Ids of the entries the search matched, or null for no search.
  final Set<String>? matching;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final m = matching;
    final pats = [
      for (final p in scope.library.patterns)
        if (m == null || p.examples.any((x) => m.contains(x.sentence.id) || x.sentence.related.any((r) => m.contains(r.id)))) p,
    ];
    if (pats.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No patterns match.')));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('How Chinese puts a sentence together, next to English. Each pattern uses sentences from your phrasebook.',
              style: theme.textTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.view_week_outlined),
            label: const Text('Practise: build the sentence'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuildSentenceScreen())),
          ),
        ),
        for (final p in pats)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatternScreen(p))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(p.name, style: theme.textTheme.titleMedium)),
                        Text('${p.examples.length} sentences', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (p.examples.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.examples.first.sentence.simplified, style: theme.textTheme.titleLarge),
                      Text(p.examples.first.sentence.gloss, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One pattern: its rule, then each example in English order and Chinese order.
class PatternScreen extends StatelessWidget {
  const PatternScreen(this.pattern, {super.key});
  final SentencePattern pattern;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final p = pattern;
    Widget row(String label, List<Widget> chunks) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: chunks),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: Readable(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(p.rule, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          for (final x in p.examples)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    row('ENGLISH', [for (final c in x.en) _ChunkBox(c)]),
                    const SizedBox(height: 6),
                    row('CHINESE', [
                      for (final (i, c) in x.zh.indexed) _ChunkBox(c, pinyin: x.zhPinyin[i], big: true),
                    ]),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                          onPressed: () => scope.speaker
                              .play(x.sentence, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(x.sentence))),
                          child: const Text('Open sentence'),
                        ),
                        const Spacer(),
                        StarButton(x.sentence),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.view_week_outlined),
            label: const Text('Practise this'),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuildSentenceScreen(only: p))),
          ),
          const SizedBox(height: 16),
          Text('Rule: Chinese Grammar Wiki, "${p.sourceTitle}"', style: theme.textTheme.bodySmall),
          SelectableText(p.sourceUrl, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(patternsSourceNote, style: theme.textTheme.bodySmall),
        ],
      )),
    );
  }
}

/// On a sentence page: the patterns it is an example of.
class PatternLinks extends StatelessWidget {
  const PatternLinks(this.patterns, {super.key});
  final List<SentencePattern> patterns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (patterns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Word order', style: theme.textTheme.titleSmall),
          for (final p in patterns)
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ListTile(
                leading: const Icon(Icons.view_week_outlined),
                title: Text(p.name),
                subtitle: const Text('See how the word order works'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatternScreen(p))),
              ),
            ),
        ],
      ),
    );
  }
}

/// [items] in an order that is never already right (when that is possible).
List<int> shuffledOrder(List<Chunk> items, Random rnd) {
  final order = List.generate(items.length, (i) => i);
  bool inOrder(List<int> o) => [for (final i in o) items[i].text].join('\u0000') == [for (final c in items) c.text].join('\u0000');
  for (var tries = 0; tries < 20; tries++) {
    order.shuffle(rnd);
    if (!inOrder(order)) break;
  }
  return order;
}

/// Questions for "Build the sentence": every example, patterns mixed, or one pattern's.
List<PatternExample> buildQuestions(Library lib, Random rnd, {SentencePattern? only, int count = 10}) {
  final pool = [
    for (final p in only == null ? lib.patterns : [only])
      for (final x in p.examples)
        if (x.zh.length >= 2) x,
  ]..shuffle(rnd);
  return pool.take(count).toList();
}

/// "Build the sentence": see the English, tap the Chinese chunks into order.
class BuildSentenceScreen extends StatefulWidget {
  const BuildSentenceScreen({super.key, this.only, this.random});
  final SentencePattern? only;
  final Random? random;

  @override
  State<BuildSentenceScreen> createState() => _BuildSentenceScreenState();
}

class _BuildSentenceScreenState extends State<BuildSentenceScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<PatternExample>? _queue;
  List<int> _tiles = [];
  final List<int> _picked = [];
  bool _checked = false;
  int _done = 0, _right = 0;
  DateTime _shownAt = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    _queue = buildQuestions(AppScope.of(context).library, _rnd, only: widget.only);
    _deal();
  }

  void _deal() {
    _picked.clear();
    _checked = false;
    _shownAt = DateTime.now();
    _tiles = _queue!.isEmpty ? [] : shuffledOrder(_queue!.first.zh, _rnd);
  }

  bool _rightAt(PatternExample x, int place) => x.zh[_picked[place]].text == x.zh[place].text;

  void _check() {
    final x = _queue!.first;
    final right = [for (var i = 0; i < _picked.length; i++) _rightAt(x, i)].every((r) => r);
    final now = DateTime.now();
    final scope = AppScope.of(context);
    scope.store.logAnswer(right ? Rating.good : Rating.again, now.difference(_shownAt), now, method: 'build', id: x.sentence.id);
    scope.speaker.play(x.sentence, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
    setState(() {
      _checked = true;
      _done++;
      if (right) _right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue!;
    final dark = theme.brightness == Brightness.dark;
    final good = dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
    final bad = dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);
    return Scaffold(
      appBar: AppBar(title: const Text('Build the sentence')),
      body: Readable(child: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_done == 0 ? 'No sentences to build yet.' : 'All done: $_right of $_done right.',
                    style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              ),
            )
          : SafeArea(
              top: false,
              child: Builder(builder: (context) {
                final x = queue.first;
                final allRight = _checked && [for (var i = 0; i < _picked.length; i++) _rightAt(x, i)].every((r) => r);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${queue.length} left · $_right of $_done right', style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Put it in Chinese order', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(x.sentence.gloss, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(minHeight: 72),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant, width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < _picked.length; i++)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_checked ? theme.colorScheme.surfaceContainerHighest : _rightAt(x, i) ? good : bad,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(x.zh[_picked[i]].text, style: theme.textTheme.titleLarge),
                                        if (_checked) ...[
                                          Text(x.zhPinyin[_picked[i]], style: theme.textTheme.bodySmall),
                                          Text(_rightAt(x, i) ? '✓ right' : '✗ should be ${x.zh[i].text}',
                                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final n in _tiles)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(72, 52)),
                                  onPressed: _checked || _picked.contains(n) ? null : () => setState(() => _picked.add(n)),
                                  child: Text(x.zh[n].text, style: theme.textTheme.titleLarge),
                                ),
                            ],
                          ),
                          if (_checked) ...[
                            const SizedBox(height: 16),
                            Text(allRight ? 'All in order!' : 'Not quite. Each red chunk shows what belongs there.',
                                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(x.sentence.simplified, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                            Text(x.sentence.pinyin, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                            for (final p in AppScope.of(context).library.patternsFor(x.sentence))
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatternScreen(p))),
                                child: Text('Why: ${p.name}'),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _checked
                          ? SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => setState(() {
                                  queue.removeAt(0);
                                  _deal();
                                }),
                                child: const Text('Next'),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _picked.isEmpty ? null : () => setState(_picked.clear),
                                    child: const Text('Start again'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _picked.length == x.zh.length ? _check : null,
                                    child: const Text('Check'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              }),
            )),
    );
  }
}
