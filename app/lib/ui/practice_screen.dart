import 'dart:math';

import 'package:flutter/material.dart';

import '../data/user_store.dart';
import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'common.dart';

/// One flashcard to show: an entry in one direction.
class PracticeCard {
  const PracticeCard(this.entry, this.direction, {this.relatedTo});
  final Entry entry;
  final Direction direction;

  /// Set when this is a related word mixed in from outside the list.
  final Entry? relatedTo;
}

/// Builds the session queue: due cards first, then new ones (at most [maxNew]),
/// then, with [includeNotDue], the rest. With [limit] above 0, picks that many at
/// random, still due cards first. With [related] above 0, mixes in up to that many
/// related words that are not in [entries], from [library].
List<PracticeCard> buildQueue({
  required List<Entry> entries,
  required UserStore store,
  required DateTime now,
  bool includeNotDue = false,
  int maxNew = 20,
  int limit = 0,
  int related = 0,
  Map<String, Entry> library = const {},
  Random? random,
}) {
  const sched = Scheduler();
  final rnd = random ?? Random();
  final due = <PracticeCard>[];
  final fresh = <PracticeCard>[];
  final rest = <PracticeCard>[];
  for (final e in entries) {
    for (final d in Direction.values) {
      final c = store.card(e.id, d);
      if (c == null) {
        fresh.add(PracticeCard(e, d));
      } else if (sched.isDue(c, now)) {
        due.add(PracticeCard(e, d));
      } else if (includeNotDue) {
        rest.add(PracticeCard(e, d));
      }
    }
  }
  if (limit > 0) {
    due.shuffle(rnd);
    fresh.shuffle(rnd);
    rest.shuffle(rnd);
  } else {
    due.sort((a, b) => store.card(a.entry.id, a.direction)!.due.compareTo(store.card(b.entry.id, b.direction)!.due));
  }
  // Learn Chinese -> English first; the reverse card of a new word comes after it.
  final freshFirst = [
    for (final d in Direction.values) ...fresh.where((c) => c.direction == d),
  ];
  var queue = [...due, ...freshFirst.take(maxNew), ...rest];
  if (limit > 0 && queue.length > limit) queue = queue.sublist(0, limit);
  if (limit > 0) {
    queue.shuffle(rnd);
    // Still see a word's Chinese side before its English side.
    final firstAt = <String, int>{};
    for (var i = 0; i < queue.length; i++) {
      final at = firstAt[queue[i].entry.id];
      if (at == null) {
        firstAt[queue[i].entry.id] = i;
      } else if (queue[i].direction == Direction.zhToEn) {
        final t = queue[at];
        queue[at] = queue[i];
        queue[i] = t;
      }
    }
  }

  if (related > 0 && queue.isNotEmpty) {
    final inList = {for (final e in entries) e.id};
    final seen = <String>{};
    final options = <PracticeCard>[];
    for (final c in queue) {
      for (final r in c.entry.related) {
        final e = library[r.id];
        if (e == null || inList.contains(r.id) || !seen.add(r.id)) continue;
        options.add(PracticeCard(e, Direction.zhToEn, relatedTo: c.entry));
      }
    }
    options.shuffle(rnd);
    for (final c in options.take(related)) {
      // Never first, so the session opens with one of the learner's own words.
      queue.insert(1 + rnd.nextInt(queue.length), c);
    }
  }
  return queue;
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.list, this.level, this.includeNotDue = false});

  /// Custom list to practise, or null for all starred words.
  final String? list;

  /// Only words the learner scored this hard, or null for all of them.
  final Difficulty? level;
  final bool includeNotDue;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  static const _sched = Scheduler();
  List<PracticeCard>? _queue;
  int _done = 0;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final scope = AppScope.of(context);
    final entries = [
      for (final id in scope.store.idsIn(widget.list))
        if (scope.library.byId[id] != null &&
            (widget.level == null || scope.store.difficulty[id] == widget.level))
          scope.library.byId[id]!,
    ];
    final size = scope.store.sessionSize;
    _queue = buildQueue(
      entries: entries,
      store: scope.store,
      now: DateTime.now(),
      includeNotDue: widget.includeNotDue,
      limit: size,
      // About one related word for every five cards.
      related: scope.store.mixRelated ? max(1, (size == 0 ? entries.length * 2 : size) ~/ 5) : 0,
      library: scope.library.byId,
    );
    _shownAt = DateTime.now();
  }

  DateTime _shownAt = DateTime.now();

  void _rate(Rating r) {
    final scope = AppScope.of(context);
    final card = _queue!.removeAt(0);
    final now = DateTime.now();
    final next = _sched.review(scope.store.card(card.entry.id, card.direction), r, now);
    scope.store.recordReview(card.entry.id, card.direction, next, r, now.difference(_shownAt), now);
    _shownAt = now;
    if (r == Rating.again) {
      // See it again a few cards later in this session.
      _queue!.insert(_queue!.length < 3 ? _queue!.length : 3, card);
    } else {
      _done++;
    }
    setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final queue = _queue!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Card front',
            icon: const Icon(Icons.tune),
            initialValue: store.cardFront,
            onSelected: (v) => setState(() => store.setCardFront(v)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'hanzi', child: Text('Chinese cards show hanzi')),
              PopupMenuItem(value: 'pinyin', child: Text('Chinese cards show pinyin')),
              PopupMenuItem(value: 'audio', child: Text('Chinese cards are audio only')),
            ],
          ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _done == 0 ? 'Nothing to practise yet. Star some words first.' : 'All done: $_done cards reviewed.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          // Keeps the buttons above the phone's own navigation bar.
          : SafeArea(top: false, child: _buildCard(context, queue.first, queue.length)),
    );
  }

  Widget _buildCard(BuildContext context, PracticeCard card, int left) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final e = card.entry;
    final now = DateTime.now();
    final state = store.card(e.id, card.direction);
    final zhFront = card.direction == Direction.zhToEn;

    void play() => scope.speaker.play(e, female: store.femaleVoice, slow: store.slowAudio);

    Widget front;
    if (zhFront) {
      front = switch (store.cardFront) {
        'pinyin' => PinyinText(e, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
        'audio' => IconButton.filledTonal(iconSize: 48, icon: const Icon(Icons.volume_up), onPressed: play),
        _ => HanziText(e,
            style: e.isSentence ? theme.textTheme.headlineMedium : theme.textTheme.displayMedium,
            textAlign: TextAlign.center),
      };
    } else {
      front = Text(e.gloss, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center);
    }

    final back = <Widget>[
      if (!zhFront || store.cardFront != 'hanzi')
        HanziText(e,
            style: e.isSentence ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall,
            textAlign: TextAlign.center),
      if (!zhFront || store.cardFront != 'pinyin')
        PinyinText(e, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
      if (zhFront) Text(e.gloss, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Female'),
            onPressed: () => scope.speaker.play(e, female: true, slow: store.slowAudio),
          ),
          TextButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Male'),
            onPressed: () => scope.speaker.play(e, female: false, slow: store.slowAudio),
          ),
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          Text(
            '${zhFront ? 'Chinese → English' : 'English → Chinese'} · $left left',
            style: theme.textTheme.bodySmall,
          ),
          if (card.relatedTo case final from?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text('Related word, from ${from.simplified}',
                        style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  ListenableBuilder(
                    listenable: store,
                    builder: (context, _) => TextButton.icon(
                      icon: Icon(store.isStarred(e.id) ? Icons.star : Icons.star_outline),
                      label: Text(store.isStarred(e.id) ? 'In Focus' : 'Add to Focus'),
                      onPressed: () => store.toggleStar(e.id),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _revealed = true),
              child: Card(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        front,
                        const SizedBox(height: 16),
                        if (_revealed) ...[const Divider(), ...back]
                        else Text('Tap to show the answer', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_revealed)
            Row(
              children: [
                for (final r in Rating.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(backgroundColor: _ratingColor(r, theme)),
                            onPressed: () => _rate(r),
                            child: Text(_ratingLabel(r)),
                          ),
                          const SizedBox(height: 4),
                          Text(_sched.preview(state, r, now), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => setState(() => _revealed = true), child: const Text('Show answer')),
            ),
          const SizedBox(height: 8),
          Text('How well you knew it sets when the card comes back.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _ratingLabel(Rating r) => switch (r) {
        Rating.again => 'Again',
        Rating.hard => 'Hard',
        Rating.good => 'Good',
        Rating.easy => 'Easy',
      };

  Color _ratingColor(Rating r, ThemeData t) {
    final dark = t.brightness == Brightness.dark;
    return switch (r) {
      Rating.again => dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6),
      Rating.hard => dark ? const Color(0xFF5A4A1F) : const Color(0xFFFFEFC2),
      Rating.good => dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6),
      Rating.easy => dark ? const Color(0xFF1F3F5C) : const Color(0xFFD6E8FF),
    };
  }
}
