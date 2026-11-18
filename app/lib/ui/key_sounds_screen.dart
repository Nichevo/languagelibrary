import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/key_sounds.dart';
import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'sounds_screen.dart';
import 'wide.dart';

/// Where the pairs come from, shown under each group's tip.
const keySoundsSourceNote = 'Pairs are words from your library that differ in one sound. '
    'Pinyin from HSK and CC-CEDICT; voices are the library\'s own clips.';

/// Rounds in one set.
const keySoundsSetSize = 10;

/// Practice > Key sounds: your trouble sounds, then every group.
class KeySoundsHome extends StatelessWidget {
  const KeySoundsHome({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final ks = scope.library.keySounds;
    final store = scope.store;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Key sounds')),
      body: Readable(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final scores = contrastScores(store.soundTries);
            final trouble = troubleSounds(store.soundTries);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _TroubleCard(trouble: trouble, scores: scores, keySounds: ks),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text('All groups', style: theme.textTheme.titleMedium),
                ),
                for (final g in ks.groups) _GroupTile(group: g, scores: scores),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Mix all groups'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => SoundQuizScreen(trouble: trouble))),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.hearing),
                  title: const Text('Hear it, pick the tone'),
                  subtitle: const Text('The four-tone quiz: one syllable, every tone it has'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToneQuizScreen())),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TroubleCard extends StatelessWidget {
  const _TroubleCard({required this.trouble, required this.scores, required this.keySounds});
  final List<String> trouble;
  final Map<String, ContrastScore> scores;
  final KeySounds keySounds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (trouble.isEmpty) {
      return Card(
        color: cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your trouble sounds', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('Hear one word, pick which of two it was. Sounds you often mix up '
                  'show here after a few sets, and come up more often.'),
            ],
          ),
        ),
      );
    }
    return Card(
      color: cs.errorContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your trouble sounds', style: theme.textTheme.titleMedium),
            Text('From your last $window tries of each', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final id in trouble.take(4))
              _ScoreRow(label: keySounds.contrast(id)?.label ?? id, score: scores[id]!, warn: true),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SoundQuizScreen(trouble: trouble, troubleOnly: true))),
                child: const Text('Practise my trouble sounds'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score, this.warn = false});
  final String label;
  final ContrastScore score;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('${score.right} of ${score.total} right', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: score.share,
            color: warn ? theme.colorScheme.error : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.scores});
  final SoundGroup group;
  final Map<String, ContrastScore> scores;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final count = scope.library.keySounds.shown(scope.library, scope.store.shows, group: group.id).length;
    var right = 0, total = 0;
    for (final c in group.contrasts) {
      final s = scores[c.id];
      if (s != null) {
        right += s.right;
        total += s.total;
      }
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: count == 0
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KeySoundsGroupScreen(group: group))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(group.title, style: theme.textTheme.titleSmall)),
                Text(count == 1 ? '1 pair' : '$count pairs', style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 6),
              if (total == 0)
                Text('Not tried yet', style: theme.textTheme.bodySmall)
              else ...[
                LinearProgressIndicator(value: right / total, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 3),
                Text('$right of $total heard right lately', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One group: how to make the sounds, then its pairs to hear.
class KeySoundsGroupScreen extends StatefulWidget {
  const KeySoundsGroupScreen({super.key, required this.group});
  final SoundGroup group;

  @override
  State<KeySoundsGroupScreen> createState() => _KeySoundsGroupScreenState();
}

class _KeySoundsGroupScreenState extends State<KeySoundsGroupScreen> {
  String? _contrast;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final g = widget.group;
    final all = scope.library.keySounds.shown(scope.library, scope.store.shows, group: g.id);
    final pairs = [for (final p in all) if (_contrast == null || p.pair.contrast == _contrast) p];
    int countOf(String c) => all.where((p) => p.pair.contrast == c).length;
    return Scaffold(
      appBar: AppBar(title: Text(g.title)),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How to tell them apart', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(g.tip),
                    const SizedBox(height: 6),
                    Text('Summarised from Wikipedia, "Standard Chinese phonology" (CC BY-SA 4.0). $keySoundsSourceNote',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('All ${all.length}'),
                  selected: _contrast == null,
                  onSelected: (_) => setState(() => _contrast = null),
                ),
                for (final c in g.contrasts)
                  if (countOf(c.id) > 0)
                    ChoiceChip(
                      label: Text('${c.label} · ${countOf(c.id)}'),
                      selected: _contrast == c.id,
                      onSelected: (_) => setState(() => _contrast = c.id),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in pairs) _PairRow(pair: p, kind: g.kind),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.hearing),
              label: Text(_contrast == null ? 'Practise this group' : 'Practise ${scope.library.keySounds.contrast(_contrast!)?.label}'),
              onPressed: pairs.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SoundQuizScreen(group: g.id, contrast: _contrast,
                          trouble: troubleSounds(scope.store.soundTries)))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({required this.pair, required this.kind});
  final ShownPair pair;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    Widget side(Entry e, Entry other) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => scope.speaker.play(e, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                Text(e.simplified, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkedPinyin(e, other, kind: kind),
                      Text(shortMeaning(e), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.volume_up_outlined, size: 18),
              ]),
            ),
          ),
        );
    return Card(
      child: Row(children: [side(pair.a, pair.b), const SizedBox(width: 4), side(pair.b, pair.a)]),
    );
  }
}

/// [e]'s pinyin with the part that differs from [other] coloured.
class MarkedPinyin extends StatelessWidget {
  const MarkedPinyin(this.e, this.other, {super.key, required this.kind, this.style});
  final Entry e, other;
  final String kind;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = e.pinyin;
    final s = e.syllables.first;
    var (start, end) = switch (kind) {
      'initial' when p.startsWith(s.initial) => (0, s.initial.length),
      'final' when p.startsWith(s.initial) => (s.initial.length, p.length),
      _ => differingPart(p, other.pinyin),
    };
    if (end <= start) (start, end) = (0, p.length);
    final mark = Theme.of(context).colorScheme.error;
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: p.substring(0, start)),
      TextSpan(text: p.substring(start, end), style: TextStyle(color: mark, fontWeight: FontWeight.w700)),
      TextSpan(text: p.substring(end)),
    ]));
  }
}

/// Hear one word, pick which of the pair it was.
class SoundQuizScreen extends StatefulWidget {
  const SoundQuizScreen(
      {super.key, this.group, this.contrast, this.trouble = const [], this.troubleOnly = false, this.random});

  /// Only this group, or only this contrast; neither means every group.
  final String? group, contrast;

  /// Trouble contrasts, which fill about 7 rounds in 10.
  final List<String> trouble;

  /// Only the trouble contrasts.
  final bool troubleOnly;
  final Random? random;

  @override
  State<SoundQuizScreen> createState() => _SoundQuizScreenState();
}

class _SoundQuizScreenState extends State<SoundQuizScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<SoundQuestion>? _queue;
  final _results = <(SoundQuestion, Entry picked)>[];
  final _retried = <SoundQuestion>{};

  /// Rounds that bring back a missed pair; the summary counts first tries only.
  final _backs = <SoundQuestion>{};
  int _round = 0;
  Entry? _picked;
  late bool _female;
  DateTime _shownAt = DateTime.now();

  KeySounds get _ks => AppScope.of(context).library.keySounds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    _female = AppScope.of(context).store.femaleVoice;
    _queue = _newSet();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  List<SoundQuestion> _newSet() {
    final scope = AppScope.of(context);
    var pool = _ks.shown(scope.library, scope.store.shows, group: widget.group, contrast: widget.contrast);
    if (widget.troubleOnly) {
      final hard = [for (final p in pool) if (widget.trouble.contains(p.pair.contrast)) p];
      if (hard.isNotEmpty) pool = hard;
    }
    return soundQuestions(pool, _rnd, count: keySoundsSetSize, trouble: widget.trouble);
  }

  SoundQuestion? get _current => _round < _queue!.length ? _queue![_round] : null;

  Future<void> _play([Entry? e, bool? female]) async {
    final q = _current;
    if (q == null || !mounted) return;
    final scope = AppScope.of(context);
    await scope.speaker.play(e ?? q.played, female: female ?? _female, slow: scope.store.slowAudio);
  }

  Future<void> _hearBoth() async {
    final q = _current!;
    await _play(q.pair.a);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) await _play(q.pair.b);
  }

  void _pick(Entry e) {
    final q = _current!;
    final store = AppScope.of(context).store;
    final now = DateTime.now();
    final right = e.id == q.played.id;
    unawaited(store.logAnswer(right ? Rating.good : Rating.again, now.difference(_shownAt), now,
        method: 'tones', id: q.played.id));
    unawaited(store.logSoundTry(SoundTry(now, q.pair.pair.contrast, q.played.id, e.id)));
    setState(() {
      _picked = e;
      _results.add((q, e));
      // A missed pair comes back once, a few rounds later.
      if (!right && _retried.add(q)) {
        final back = SoundQuestion(q.pair, _rnd.nextBool());
        _retried.add(back);
        _backs.add(back);
        _queue!.insert(min(_round + 4, _queue!.length), back);
      }
    });
  }

  void _next() {
    setState(() {
      _round++;
      _picked = null;
      _female = !_female;
      _shownAt = DateTime.now();
    });
    _play();
  }

  void _again() {
    setState(() {
      _queue = _newSet();
      _results.clear();
      _retried.clear();
      _backs.clear();
      _round = 0;
      _picked = null;
      _shownAt = DateTime.now();
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final q = _current;
    return Scaffold(
      appBar: AppBar(title: Text(q == null && _results.isNotEmpty ? 'Set done' : 'Key sounds')),
      body: Readable(
        child: _queue!.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No sound pairs at your levels yet.')))
            : q == null
                ? _summary(context)
                : _question(context, q),
      ),
    );
  }

  Widget _question(BuildContext context, SoundQuestion q) {
    final theme = Theme.of(context);
    final group = _ks.group(groupOf(q.pair.pair.contrast));
    final kind = group?.kind ?? 'tone';
    final answered = _picked != null;
    final right = answered && _picked!.id == q.played.id;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          LinearProgressIndicator(value: _round / _queue!.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!answered) ...[
                  Text('Which one did you hear?', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: IconButton.filled(
                      iconSize: 48,
                      tooltip: 'Play again',
                      icon: const Icon(Icons.volume_up),
                      onPressed: _play,
                    ),
                  ),
                  Text('Tap to hear it again · ${_female ? 'female' : 'male'} voice',
                      style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ] else
                  Card(
                    color: right ? _good(theme) : _bad(theme),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        right
                            ? 'Right: ${q.played.simplified} ${q.played.pinyin}, ${shortMeaning(q.played)}.'
                            : 'Not quite. It said ${q.played.simplified} ${q.played.pinyin}, ${shortMeaning(q.played)}. '
                                'You picked ${_picked!.simplified} ${_picked!.pinyin}.',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  _choice(context, q.pair.a, q.pair.b, q, kind),
                  const SizedBox(width: 10),
                  _choice(context, q.pair.b, q.pair.a, q, kind),
                ]),
                const SizedBox(height: 12),
                if (!answered)
                  Text(
                    switch (kind) {
                      'tone' => 'Same sounds, only the tone is different.',
                      'initial' => 'Same tone, only the first sound is different.',
                      _ => 'Same tone, only the vowel part is different.',
                    },
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  )
                else ...[
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow), label: const Text('Hear both'), onPressed: _hearBoth),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_female ? 'Male voice' : 'Female voice'),
                        onPressed: () => _play(q.played, !_female),
                      ),
                    ),
                  ]),
                  if (!right && group != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(group.tip, style: theme.textTheme.bodyMedium),
                    ),
                ],
              ],
            ),
          ),
          if (answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _next, child: const Text('Next'))),
            ),
        ],
      ),
    );
  }

  Color _good(ThemeData t) => t.brightness == Brightness.dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
  Color _bad(ThemeData t) => t.brightness == Brightness.dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);

  Widget _choice(BuildContext context, Entry e, Entry other, SoundQuestion q, String kind) {
    final theme = Theme.of(context);
    final answered = _picked != null;
    final color = !answered
        ? null
        : e.id == q.played.id
            ? _good(theme)
            : e.id == _picked!.id
                ? _bad(theme)
                : null;
    return Expanded(
      child: Card(
        color: color,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: answered ? () => _play(e) : () => _pick(e),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(children: [
              Text(e.simplified, style: const TextStyle(fontSize: 44)),
              MarkedPinyin(e, other, kind: kind, style: theme.textTheme.headlineSmall),
              Text(shortMeaning(e), style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (answered) ...[
                const SizedBox(height: 4),
                Icon(e.id == q.played.id ? Icons.check : Icons.volume_up_outlined, size: 18),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final scores = contrastScores(AppScope.of(context).store.soundTries);
    // First tries only: a pair brought back after a miss doesn't count twice.
    final first = [for (final r in _results) if (!_backs.contains(r.$1)) r];
    final right = first.where((r) => r.$2.id == r.$1.played.id).length;
    final byContrast = <String, (int, int)>{};
    for (final (q, picked) in first) {
      final (r, t) = byContrast[q.pair.pair.contrast] ?? (0, 0);
      byContrast[q.pair.pair.contrast] = (r + (picked.id == q.played.id ? 1 : 0), t + 1);
    }
    final missed = [for (final r in first) if (r.$2.id != r.$1.played.id) r];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('$right of ${first.length}', style: theme.textTheme.headlineMedium),
              Text('heard right first time', style: theme.textTheme.bodySmall),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              for (final MapEntry(key: id, value: (r, t)) in byContrast.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(_ks.contrast(id)?.label ?? id)),
                    Text('$r of $t', style: theme.textTheme.bodySmall),
                    if (scores[id] case final s? when isTrouble(s)) ...[
                      const SizedBox(width: 8),
                      Chip(label: const Text('trouble'), visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.errorContainer),
                    ],
                  ]),
                ),
            ]),
          ),
        ),
        if (missed.isNotEmpty)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('Missed', style: theme.textTheme.titleSmall),
                ),
                for (final (q, picked) in missed)
                  ListTile(
                    dense: true,
                    title: Text('${q.played.simplified} ${q.played.pinyin}'),
                    subtitle: Text('heard as ${picked.simplified} ${picked.pinyin}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Hear both',
                      onPressed: () async {
                        final scope = AppScope.of(context);
                        await scope.speaker.play(q.played, female: scope.store.femaleVoice);
                        await Future<void>.delayed(const Duration(milliseconds: 500));
                        await scope.speaker.play(picked, female: scope.store.femaleVoice);
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: _again, child: const Text('10 more'))),
        ]),
      ],
    );
  }
}
