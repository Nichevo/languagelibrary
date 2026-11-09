import 'dart:math';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'pairs_practice.dart';

/// Shown on scale screens: the order is ours, the words and meanings are not.
const scaleSourceNote = 'Order picked by this app. Words, pinyin and meanings from HSK and CC-CEDICT.';

/// The Library's "Pairs & scales" view. With a search, only scales and pairs
/// holding a matching word are listed.
class ScalesView extends StatelessWidget {
  const ScalesView({super.key, this.matching});

  /// Ids of the words the search matched, or null for no search.
  final Set<String>? matching;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final shows = scope.store.shows;
    bool hit(Entry e) => matching == null || matching!.contains(e.id);
    final scales = [
      for (final s in scope.library.scales)
        if (s.items case final items when items.any((i) => hit(i.entry))) (s, items),
    ];
    final pairs = [
      for (final p in scope.library.opposites)
        if (shows(p.a) && shows(p.b) && (hit(p.a) || hit(p.b))) p,
    ];
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
    if (scales.isEmpty && pairs.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: Text('No scales or opposites match.')),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.swap_vert),
            label: const Text('Practise pairs & scales'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PairsPracticeScreen())),
          ),
        ),
        if (scales.isNotEmpty) heading('Scales'),
        for (final (s, items) in scales)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScaleScreen(s))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.name, style: theme.textTheme.titleMedium)),
                        Text('${s.from} → ${s.to}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (n, i) in items.indexed) ...[
                          if (n > 0) Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
                          _WordChip(i.entry, highlight: matching != null && hit(i.entry)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (pairs.isNotEmpty) heading('Opposites'),
        if (pairs.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in pairs)
                ActionChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${p.a.simplified}  ↔  ${p.b.simplified}', style: theme.textTheme.titleMedium),
                      Text('${p.aEnglish} ↔ ${p.bEnglish}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  onPressed: () => _showPair(context, p.a, p.b),
                ),
            ],
          ),
      ],
    );
  }

  void _showPair(BuildContext context, Entry a, Entry b) => showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Opposites')),
          EntryTile(a),
          EntryTile(b),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _WordChip extends StatelessWidget {
  const _WordChip(this.entry, {this.highlight = false});

  final Entry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(entry.simplified, style: theme.textTheme.titleLarge),
    );
  }
}

/// A thin bar from light to strong, showing the direction of a scale.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [c.withValues(alpha: 0.15), c],
        ),
      ),
      child: SizedBox(width: vertical ? 8 : double.infinity, height: vertical ? null : 6),
    );
  }
}

/// One scale, in order, with its meanings and buttons to play, star or practise it.
class ScaleScreen extends StatefulWidget {
  const ScaleScreen(this.scale, {super.key});

  final Scale scale;

  @override
  State<ScaleScreen> createState() => _ScaleScreenState();
}

class _ScaleScreenState extends State<ScaleScreen> {
  bool _playing = false;

  Future<void> _playAll(List<ScaleItem> items) async {
    final scope = AppScope.of(context);
    setState(() => _playing = true);
    for (final i in items) {
      if (!mounted || !_playing) break;
      await scope.speaker.play(i.entry, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final s = widget.scale;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = s.items;
        final allStarred = items.every((i) => store.isStarred(i.entry.id));
        return Scaffold(
          appBar: AppBar(title: Text(s.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text('${items.length} words, from ${s.from} to ${s.to}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                    label: Text(_playing ? 'Stop' : 'Play in order'),
                    onPressed: _playing ? () => setState(() => _playing = false) : () => _playAll(items),
                  ),
                  OutlinedButton.icon(
                    icon: Icon(allStarred ? Icons.star : Icons.star_border),
                    label: Text(allStarred ? 'All starred' : 'Star all'),
                    onPressed: allStarred
                        ? null
                        : () async {
                            for (final i in items) {
                              if (!store.isStarred(i.entry.id)) await store.toggleStar(i.entry.id);
                            }
                          },
                  ),
                  if (items.length >= 3)
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderPracticeScreen(s))),
                      child: const Text('Practise'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: _ScaleBar(vertical: true)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.from, style: theme.textTheme.bodySmall),
                          for (final i in items)
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(i.entry))),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 0, 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: HanziText(i.entry, style: theme.textTheme.headlineMedium),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            PinyinText(i.entry, style: theme.textTheme.titleMedium),
                                            Text(i.meaning, style: theme.textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Play',
                                        icon: const Icon(Icons.volume_up_outlined),
                                        onPressed: () => scope.speaker.play(
                                          i.entry,
                                          female: store.femaleVoice,
                                          slow: store.slowAudio,
                                        ),
                                      ),
                                      StarButton(i.entry),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Text(s.to, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Scales always show all their words, whatever levels are switched on, so none has gaps.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(scaleSourceNote, style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

/// On a word page: the scale the word is on, with the word marked.
class ScaleCard extends StatelessWidget {
  const ScaleCard(this.scale, this.entry, {super.key});

  final Scale scale;
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = scale.items;
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('On a scale: ${scale.name}', style: theme.textTheme.titleSmall)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScaleScreen(scale))),
                  child: const Text('See all'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  for (final (n, i) in items.indexed) ...[
                    if (n > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Material(
                        color: i.entry.id == entry.id
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: i.entry.id == entry.id
                              ? BorderSide(color: theme.colorScheme.primary, width: 2)
                              : BorderSide.none,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: i.entry.id == entry.id
                              ? null
                              : () =>
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(i.entry))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            child: Column(
                              children: [
                                FittedBox(child: Text(i.entry.simplified, style: theme.textTheme.titleLarge)),
                                Text(
                                  i.short,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(0, 10, 8, 0), child: _ScaleBar()),
          ],
        ),
      ),
    );
  }
}

/// Is [picked] (entry ids, in the order tapped) the scale's order?
bool inScaleOrder(List<ScaleItem> items, List<String> picked) =>
    picked.length == items.length &&
    [for (var n = 0; n < items.length; n++) items[n].entry.id == picked[n]].every((x) => x);

/// [items] in a shuffled order that is never already the right one.
List<ScaleItem> shuffledScale(List<ScaleItem> items, Random rnd) {
  if (items.length < 2) return [...items];
  while (true) {
    final out = [...items]..shuffle(rnd);
    if (!inScaleOrder(items, [for (final i in out) i.entry.id])) return out;
  }
}

/// "Put the words in order from cold to hot": tap each word in turn, or drag
/// them into order (the learner's choice, remembered), then check.
class OrderQuestion extends StatefulWidget {
  const OrderQuestion({super.key, required this.scale, required this.items, required this.random, this.onChecked});

  final Scale scale;

  /// The words to order (those switched on), in the right order.
  final List<ScaleItem> items;
  final Random random;

  /// Called once, when the answer is checked.
  final void Function(bool right)? onChecked;

  @override
  State<OrderQuestion> createState() => _OrderQuestionState();
}

class _OrderQuestionState extends State<OrderQuestion> {
  late List<ScaleItem> _pool = shuffledScale(widget.items, widget.random);
  final List<ScaleItem> _picked = [];
  bool _checked = false;

  /// Drag mode: the words in their current order.
  late List<ScaleItem> _dragged = [..._pool];

  @override
  void didUpdateWidget(OrderQuestion old) {
    super.didUpdateWidget(old);
    if (old.scale != widget.scale || old.items.length != widget.items.length) {
      _pool = shuffledScale(widget.items, widget.random);
      _dragged = [..._pool];
      _picked.clear();
      _checked = false;
    }
  }

  void _tap(ScaleItem i) {
    if (_checked || _picked.contains(i)) return;
    setState(() => _picked.add(i));
    final scope = AppScope.of(context);
    scope.speaker.play(i.entry, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
  }

  void _check() {
    if (AppScope.of(context).store.orderByDrag) {
      _picked
        ..clear()
        ..addAll(_dragged);
    }
    final right = inScaleOrder(widget.items, [for (final i in _picked) i.entry.id]);
    setState(() => _checked = true);
    widget.onChecked?.call(right);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final good = dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
    final bad = dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);
    final items = widget.items;
    final store = AppScope.of(context).store;
    final drag = store.orderByDrag && !_checked;
    final right = _checked && inScaleOrder(items, [for (final i in _picked) i.entry.id]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Put in order', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          '${drag ? 'Drag' : 'Tap'} the words from ${widget.scale.from} to ${widget.scale.to}',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (!_checked) ...[
          const SizedBox(height: 8),
          Center(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Tap'), icon: Icon(Icons.touch_app_outlined)),
                ButtonSegment(value: true, label: Text('Drag'), icon: Icon(Icons.drag_indicator)),
              ],
              selected: {store.orderByDrag},
              onSelectionChanged: (s) {
                setState(() {
                  _picked.clear();
                  _dragged = [..._pool];
                });
                store.setOrderByDrag(s.first);
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (drag)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => setState(() => _dragged.insert(to, _dragged.removeAt(from))),
            children: [
              for (final (n, i) in _dragged.indexed)
                Card(
                  key: ValueKey(i.entry.id),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ReorderableDragStartListener(
                    index: n,
                    child: ListTile(
                      leading: Text('${n + 1}', style: theme.textTheme.bodySmall),
                      title: Text(i.entry.simplified, style: theme.textTheme.headlineSmall),
                      trailing: const Icon(Icons.drag_indicator),
                      onTap: () {
                        final scope = AppScope.of(context);
                        scope.speaker.play(i.entry, female: store.femaleVoice, slow: store.slowAudio);
                      },
                    ),
                  ),
                ),
            ],
          )
        else
          for (var n = 0; n < items.length; n++)
            Builder(
              builder: (context) {
                final i = n < _picked.length ? _picked[n] : null;
                final ok = i != null && i.entry.id == items[n].entry.id;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: !_checked ? null : (ok ? good : bad),
                  child: ListTile(
                    dense: true,
                    leading: Text('${n + 1}', style: theme.textTheme.bodySmall),
                    title: Text(i?.entry.simplified ?? '', style: theme.textTheme.titleLarge),
                    subtitle: _checked ? Text('${items[n].entry.pinyin} · ${items[n].meaning}') : null,
                    trailing: !_checked
                        ? null
                        : ok
                        ? const Icon(Icons.check)
                        : Text('Should be ${items[n].entry.simplified}', style: theme.textTheme.bodySmall),
                  ),
                );
              },
            ),
        if (!drag) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in _pool)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(96, 56)),
                  onPressed: _checked || _picked.contains(i) ? null : () => _tap(i),
                  child: Text(i.entry.simplified, style: theme.textTheme.headlineSmall),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!_checked)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: drag || _picked.isEmpty ? null : () => setState(_picked.clear),
                  child: const Text('Start again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: drag || _picked.length == items.length ? _check : null,
                  child: const Text('Check'),
                ),
              ),
            ],
          )
        else
          Text(
            right ? 'All in order!' : 'Not quite. The right order is shown above.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

/// The "Practise" button on a scale: put it in order, as many times as you like.
class OrderPracticeScreen extends StatefulWidget {
  const OrderPracticeScreen(this.scale, {super.key});

  final Scale scale;

  @override
  State<OrderPracticeScreen> createState() => _OrderPracticeScreenState();
}

class _OrderPracticeScreenState extends State<OrderPracticeScreen> {
  final _rnd = Random();
  int _round = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.scale.items;
    return Scaffold(
      appBar: AppBar(title: Text(widget.scale.name)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            OrderQuestion(
              key: ValueKey(_round),
              scale: widget.scale,
              items: items,
              random: _rnd,
              onChecked: (_) => setState(() => _done = true),
            ),
            const SizedBox(height: 12),
            if (_done)
              FilledButton(
                onPressed: () => setState(() {
                  _round++;
                  _done = false;
                }),
                child: const Text('Again'),
              ),
          ],
        ),
      ),
    );
  }
}
