import 'dart:math';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'scales_screen.dart';

/// One question in Pairs & scales practice: put a scale in order, or pick
/// the opposite of a word.
sealed class PairsQuestion {}

class OrderItem extends PairsQuestion {
  OrderItem(this.scale);
  final Scale scale;
}

class OppositeItem extends PairsQuestion {
  OppositeItem(this.word, this.english, this.answer, this.options);
  final Entry word;
  final String english;
  final Entry answer;

  /// The answer and three other words, shuffled.
  final List<Entry> options;
}

/// A session of [count] questions: about half scales, half opposites, every
/// scale before any repeats. Opposites only use words switched on in Settings.
List<PairsQuestion> pairsSession(Library library, bool Function(Entry) shows, Random rnd, {int count = 10}) {
  final scales = [...library.scales]..shuffle(rnd);
  final pairs = [
    for (final p in library.opposites)
      if (shows(p.a) && shows(p.b)) p,
  ]..shuffle(rnd);
  final words = {for (final p in pairs) ...[p.a, p.b]}.toList();
  final out = <PairsQuestion>[];
  var s = 0, p = 0;
  while (out.length < count && (s < scales.length || p < pairs.length)) {
    final wantScale = out.length.isEven ? s < scales.length : p >= pairs.length;
    if (wantScale && s < scales.length) {
      out.add(OrderItem(scales[s++]));
      continue;
    }
    final pair = pairs[p++];
    final flip = rnd.nextBool();
    final word = flip ? pair.b : pair.a;
    final english = flip ? pair.bEnglish : pair.aEnglish;
    final answer = flip ? pair.a : pair.b;
    final others = [
      for (final w in [...words]..shuffle(rnd))
        if (w.id != word.id && w.id != answer.id && w.simplified != answer.simplified) w,
    ].take(3);
    out.add(OppositeItem(word, english, answer, [answer, ...others]..shuffle(rnd)));
  }
  return out;
}

/// Practice tab → Pairs & scales: put scales in order and pick opposites.
class PairsPracticeScreen extends StatefulWidget {
  const PairsPracticeScreen({super.key, this.random});

  final Random? random;

  @override
  State<PairsPracticeScreen> createState() => _PairsPracticeScreenState();
}

class _PairsPracticeScreenState extends State<PairsPracticeScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<PairsQuestion>? _queue;
  int _done = 0, _right = 0;
  bool _answered = false;
  Entry? _picked;
  DateTime _shownAt = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final scope = AppScope.of(context);
    final size = scope.store.sessionSize;
    _queue = pairsSession(scope.library, scope.store.shows, _rnd, count: size == 0 ? 20 : size);
  }

  void _answer(bool right, String method, String id) {
    final now = DateTime.now();
    AppScope.of(context)
        .store
        .logAnswer(right ? Rating.good : Rating.again, now.difference(_shownAt), now, method: method, id: id);
    setState(() {
      _answered = true;
      _done++;
      if (right) _right++;
    });
  }

  void _next() => setState(() {
        _queue!.removeAt(0);
        _answered = false;
        _picked = null;
        _shownAt = DateTime.now();
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue!;
    return Scaffold(
      appBar: AppBar(title: const Text('Pairs & scales')),
      body: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _done == 0 ? 'No scales or opposites to practise yet.' : 'All done: $_right of $_done right.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('${queue.length} left · $_right of $_done right', style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        switch (queue.first) {
                          OrderItem(:final scale) => OrderQuestion(
                              key: ValueKey('order-${scale.name}-$_done'),
                              scale: scale,
                              items: scale.items,
                              random: _rnd,
                              onChecked: (right) => _answer(right, 'order', scale.items.first.entry.id),
                            ),
                          final OppositeItem q => _opposite(context, q),
                        },
                      ],
                    ),
                  ),
                  if (_answered)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: _next, child: const Text('Next')),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _opposite(BuildContext context, OppositeItem q) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final dark = theme.brightness == Brightness.dark;
    final good = dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
    final bad = dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pick the opposite', style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(child: HanziText(q.word, style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w500))),
        Center(child: PinyinText(q.word, style: theme.textTheme.titleMedium)),
        Text(q.english, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        for (final o in q.options)
          Card(
            color: !_answered
                ? null
                : o.id == q.answer.id
                    ? good
                    : o.id == _picked?.id
                        ? bad
                        : null,
            child: ListTile(
              title: Text(o.simplified, style: theme.textTheme.headlineSmall),
              subtitle: _answered ? Text('${o.pinyin} · ${o.gloss}') : null,
              trailing: _answered && o.id == q.answer.id ? const Icon(Icons.check) : null,
              onTap: _answered
                  ? null
                  : () {
                      _picked = o;
                      _answer(o.id == q.answer.id, 'opposite', q.word.id);
                      scope.speaker.play(q.answer, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
                    },
            ),
          ),
        if (_answered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${q.word.simplified} ${q.english} ↔ ${q.answer.simplified}',
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
