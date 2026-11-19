import 'dart:math';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'pairs_practice.dart';
import 'wide.dart';

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
          body: Readable(child: ListView(
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
          )),
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

/// Where place [p] (from 0) of [count] is, for hints: "first", "in place 3",
/// "last". The question already says which end is first.
String scalePlace(int p, int count) => p == 0
    ? 'first'
    : p == count - 1
        ? 'last'
        : 'in place ${p + 1}';

/// [arranged] with the words of the [locked] places moved back to their right
/// places; the other words keep their order around them.
List<ScaleItem> pinLocked(List<ScaleItem> items, Set<int> locked, List<ScaleItem> arranged) {
  final lockedItems = {for (final p in locked) items[p]};
  final rest = [for (final i in arranged) if (!lockedItems.contains(i)) i];
  return [for (var n = 0; n < items.length; n++) locked.contains(n) ? items[n] : rest.removeAt(0)];
}

/// One hint given after a wrong check: [item] belongs in place [place].
typedef OrderHint = ({ScaleItem item, int place});

/// "Put the words in order from cold to hot": tap each word in turn, or drag
/// them into order (the learner's choice, remembered), then check.
///
/// A wrong check teaches instead of ending the question: every word already
/// in its right place turns green, stays put and shows its pinyin and
/// English, and one more word is moved to its place with a hint saying what
/// it means. Check again, as often as needed, or show the answer.
class OrderQuestion extends StatefulWidget {
  const OrderQuestion({super.key, required this.scale, required this.items, required this.random, this.onChecked});

  final Scale scale;

  /// The words to order (those switched on), in the right order.
  final List<ScaleItem> items;
  final Random random;

  /// Called once, when the question is finished (in order, or the answer
  /// shown): right only when it was in order on the first check.
  final void Function(bool right)? onChecked;

  @override
  State<OrderQuestion> createState() => _OrderQuestionState();
}

class _OrderQuestionState extends State<OrderQuestion> {
  late List<ScaleItem> _pool;

  /// Tap mode: the word put in each place so far.
  late List<ScaleItem?> _slots;

  /// Drag mode: the words in their current order.
  late List<ScaleItem> _dragged;

  /// Places found right by a check or a hint: green and fixed.
  final Set<int> _locked = {};
  final List<OrderHint> _hints = [];
  int _checks = 0;
  bool _finished = false, _gaveUp = false;

  /// Once finished: the words shown in each place.
  List<ScaleItem?> _final = const [];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _pool = shuffledScale(widget.items, widget.random);
    _slots = List.filled(widget.items.length, null);
    _dragged = [..._pool];
    _locked.clear();
    _hints.clear();
    _checks = 0;
    _finished = _gaveUp = false;
  }

  @override
  void didUpdateWidget(OrderQuestion old) {
    super.didUpdateWidget(old);
    if (old.scale != widget.scale || old.items.length != widget.items.length) _reset();
  }

  bool get _drag => AppScope.of(context).store.orderByDrag;

  /// The current answer, place by place.
  List<ScaleItem?> get _current => _drag ? _dragged : _slots;

  /// Empties the places not yet found right (tap mode), and puts the found
  /// words back in their places (drag mode).
  void _clearOpen() {
    final items = widget.items;
    _slots = [for (var n = 0; n < items.length; n++) _locked.contains(n) ? items[n] : null];
    _dragged = pinLocked(items, _locked, _drag ? _dragged : _pool);
  }

  void _play(ScaleItem i) {
    final scope = AppScope.of(context);
    scope.speaker.play(i.entry, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
  }

  void _tap(ScaleItem i) {
    if (_finished || _slots.contains(i)) return;
    final open = _slots.indexOf(null);
    if (open < 0) return;
    setState(() => _slots[open] = i);
    _play(i);
  }

  void _check() {
    final items = widget.items;
    final current = _current;
    _checks++;
    for (var n = 0; n < items.length; n++) {
      if (current[n] == items[n]) _locked.add(n);
    }
    if (_locked.length < items.length) {
      // One hint: the first place still wrong, from the start of the scale.
      final p = [for (var n = 0; n < items.length; n++) n].firstWhere((n) => !_locked.contains(n));
      _locked.add(p);
      _hints.add((item: items[p], place: p));
      // With one word left there is nothing left to work out.
      if (_locked.length >= items.length - 1) _locked.addAll([for (var n = 0; n < items.length; n++) n]);
    }
    if (_locked.length == items.length) {
      _final = [...items];
      _finish();
    } else {
      setState(_clearOpen);
    }
  }

  void _showAnswer() {
    // Keep the words where they are now, to compare with the right ones.
    _final = [..._current];
    _gaveUp = true;
    _finish();
  }

  void _finish() {
    setState(() => _finished = true);
    widget.onChecked?.call(_checks == 1 && _hints.isEmpty && !_gaveUp);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final good = dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
    final bad = dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);
    final items = widget.items;
    final store = AppScope.of(context).store;
    final drag = store.orderByDrag && !_finished;
    final tapFull = !_slots.contains(null);
    final open = items.length - _locked.length;
    Widget lockedRow(int n) => OrderResultRow(position: n + 1, yours: items[n], answer: items[n], good: good, bad: bad);
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
        if (!_finished) ...[
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
                store.setOrderByDrag(s.first);
                setState(() {
                  _slots = [for (var n = 0; n < items.length; n++) _locked.contains(n) ? items[n] : null];
                  _dragged = pinLocked(items, _locked, _pool);
                });
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
            onReorderItem: (from, to) => setState(() {
              _dragged.insert(to, _dragged.removeAt(from));
              _dragged = pinLocked(items, _locked, _dragged);
            }),
            children: [
              for (final (n, i) in _dragged.indexed)
                if (_locked.contains(n))
                  KeyedSubtree(key: ValueKey(i.entry.id), child: lockedRow(n))
                else
                  Card(
                    key: ValueKey(i.entry.id),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ReorderableDragStartListener(
                      index: n,
                      child: ListTile(
                        leading: Text('${n + 1}', style: theme.textTheme.bodySmall),
                        title: Text(i.entry.simplified, style: theme.textTheme.headlineSmall),
                        trailing: const Icon(Icons.drag_indicator),
                        onTap: () => _play(i),
                      ),
                    ),
                  ),
            ],
          )
        else
          for (var n = 0; n < items.length; n++)
            Builder(
              builder: (context) {
                if (_finished) {
                  return OrderResultRow(position: n + 1, yours: _final[n], answer: items[n], good: good, bad: bad);
                }
                final i = _slots[n];
                if (_locked.contains(n)) return lockedRow(n);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: Text('${n + 1}', style: theme.textTheme.bodySmall),
                    title: Text(i?.entry.simplified ?? '', style: theme.textTheme.titleLarge),
                    // Tap a placed word to take it back out.
                    onTap: i == null ? null : () => setState(() => _slots[n] = null),
                  ),
                );
              },
            ),
        if (!drag && !_finished) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in _pool)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(96, 56)),
                  onPressed: _slots.contains(i) ? null : () => _tap(i),
                  child: Text(i.entry.simplified, style: theme.textTheme.headlineSmall),
                ),
            ],
          ),
        ],
        if (_hints.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (n, h) in _hints.indexed)
            OrderHintCard(number: n + 1, hint: h, place: scalePlace(h.place, items.length)),
        ],
        const SizedBox(height: 16),
        if (!_finished) ...[
          if (_checks > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_locked.length} of ${items.length} in place. '
                '${drag ? 'Move' : 'Tap'} the other $open into order and check again.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _checks > 0
                    ? OutlinedButton(onPressed: _showAnswer, child: const Text('Show answer'))
                    : OutlinedButton(
                        onPressed: drag || !_slots.any((s) => s != null) ? null : () => setState(_clearOpen),
                        child: const Text('Start again'),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: drag || tapFull ? _check : null,
                  child: Text(_checks == 0 ? 'Check' : 'Check again'),
                ),
              ),
            ],
          ),
        ] else
          Text(
            _gaveUp
                ? 'Here is the order. Each red place shows the word that belongs there. Tap a word to hear it.'
                : _checks == 1 && _hints.isEmpty
                    ? 'All in order!'
                    : 'In order, with ${_hints.length} ${_hints.length == 1 ? 'hint' : 'hints'}. Tap a word to hear it.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

/// A hint after a wrong check: the word, its pinyin and English (from the
/// library), and the place it goes.
class OrderHintCard extends StatelessWidget {
  const OrderHintCard({super.key, required this.number, required this.hint, required this.place});

  final int number;
  final OrderHint hint;

  /// Where it goes, as words: "first", "in place 3".
  final String place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final i = hint.item;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.lightbulb_outline),
        title: Text('Hint $number', style: theme.textTheme.labelLarge),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(i.entry.simplified, style: theme.textTheme.titleLarge),
            Text(i.entry.pinyin, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary)),
            Text('means "${i.short}", so it goes $place.', style: theme.textTheme.bodyLarge),
          ],
        ),
        onTap: () => scope.speaker.play(i.entry, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
      ),
    );
  }
}

/// One checked place in a put-in-order answer: the word put there, with its
/// pinyin and English, marked right or wrong, and the right word when wrong.
class OrderResultRow extends StatelessWidget {
  const OrderResultRow({
    super.key,
    required this.position,
    required this.yours,
    required this.answer,
    required this.good,
    required this.bad,
  });

  final int position;

  /// The word the learner put in this place.
  final ScaleItem? yours;

  /// The word that belongs here.
  final ScaleItem answer;
  final Color good;
  final Color bad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final mine = yours;
    final ok = mine?.entry.id == answer.entry.id;
    Widget word(ScaleItem w, TextStyle? hanzi) => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(w.entry.simplified, style: hanzi),
        Text(w.entry.pinyin, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary)),
        Text(w.short, style: theme.textTheme.bodyLarge),
      ],
    );
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: ok ? good : bad,
      child: ListTile(
        leading: Text('$position', style: theme.textTheme.bodySmall),
        title: mine == null ? const Text('—') : word(mine, theme.textTheme.titleLarge),
        subtitle: ok
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text('Should be', style: theme.textTheme.bodySmall),
                    word(answer, theme.textTheme.titleMedium),
                  ],
                ),
              ),
        trailing: Icon(ok ? Icons.check_circle : Icons.cancel, semanticLabel: ok ? 'Right' : 'Wrong'),
        onTap: mine == null
            ? null
            : () => scope.speaker.play(mine.entry, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
      ),
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
      body: Readable(child: SafeArea(
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
      )),
    );
  }
}
