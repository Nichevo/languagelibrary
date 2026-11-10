import 'dart:math';

import 'package:flutter/material.dart';

import '../data/sounds.dart';
import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';

/// The first meaning, without bracketed notes: "hemp", "to say".
String shortMeaning(Entry e) =>
    e.meanings.isEmpty ? '' : e.meanings.first.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split(';').first.trim();

/// The Library's "Tricky sounds" view: words told apart only by tone,
/// characters with two readings, words that sound the same, and tone changes.
/// With a search, only groups holding a matching word are listed.
class SoundsView extends StatefulWidget {
  const SoundsView({super.key, this.matching});

  /// Ids of the words the search matched, or null for no search.
  final Set<String>? matching;

  @override
  State<SoundsView> createState() => _SoundsViewState();
}

class _SoundsViewState extends State<SoundsView> {
  bool _allSets = false, _allSame = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lib = scope.library;
    final theme = Theme.of(context);
    final m = widget.matching;
    bool hit(Iterable<Entry> es) => m == null || es.any((e) => m.contains(e.id));
    final sets = [for (final s in toneSets(lib)) if (hit(s.words)) s];
    final four = [for (final s in sets) if (s.byTone.length == 4) s];
    final three = [for (final s in sets) if (s.byTone.length == 3) s];
    final twos = [for (final t in twoSounds(lib)) if (hit(t.readings)) t];
    final same = [for (final s in sameSounds(lib)) if (hit(s.words)) s];
    final rules = [for (final r in toneRules(lib)) if (hit(r.words)) r];
    Widget heading(String text, [String? detail]) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: theme.textTheme.titleMedium),
              if (detail != null) Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    Widget more(bool open, int hidden, VoidCallback onTap) => hidden <= 0
        ? const SizedBox.shrink()
        : Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onTap, child: Text(open ? 'Show fewer' : 'Show $hidden more')),
          );
    if (sets.isEmpty && twos.isEmpty && same.isEmpty && rules.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No tricky sounds match.')));
    }
    final threeShown = _allSets || m != null ? three : three.take(6).toList();
    final sameShown = _allSame || m != null ? same : same.take(8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.hearing),
            label: const Text('Practise: hear it, pick the tone'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToneQuizScreen())),
          ),
        ),
        if (four.isNotEmpty || three.isNotEmpty)
          heading('One sound, different tones', 'Change the tone and you have a different word. Tap a set to hear it.'),
        for (final s in [...four, ...threeShown]) ToneSetCard(s),
        if (m == null) more(_allSets, three.length - 6, () => setState(() => _allSets = !_allSets)),
        if (twos.isNotEmpty)
          heading('One character, two sounds', 'The same character is read differently in different words.'),
        if (twos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in twos)
                ActionChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.hanzi, style: theme.textTheme.titleLarge),
                      Text.rich(TextSpan(children: [
                        for (final (i, e) in t.readings.indexed) ...[
                          if (i > 0) const TextSpan(text: ' · '),
                          TextSpan(
                            text: e.pinyin,
                            style: TextStyle(color: toneColor(e.syllables.first.tone, theme.brightness)),
                          ),
                        ],
                      ])),
                    ],
                  ),
                  onPressed: () => _sheet(context, '${t.hanzi}: ${t.readings.length} readings', t.readings),
                ),
            ],
          ),
        if (same.isNotEmpty)
          heading('Same sound, different words',
              'These HSK 1 to 4 characters sound exactly alike. Context, or the word they are in, tells them apart.'),
        for (final s in sameShown)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _sheet(context, 'All said ${s.pinyin}', s.words),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(s.pinyin,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: toneColor(s.words.first.syllables.first.tone, theme.brightness))),
                    ),
                    Expanded(
                      child: Text(
                        [for (final e in s.words) e.simplified].join('  '),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    Text('${s.words.length}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        if (m == null) more(_allSame, same.length - 8, () => setState(() => _allSame = !_allSame)),
        if (rules.isNotEmpty)
          heading('Tones that change', 'Some tones are said differently next to others. The word pages show how each word is said.'),
        for (final r in rules) _RuleCard(r),
        const SizedBox(height: 16),
        Text(soundsSourceNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

void _sheet(BuildContext context, String title, List<Entry> words) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(title)),
              for (final e in words) EntryTile(e),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

/// A tone set in a list: one tile per tone, in the tone's colour.
class ToneSetCard extends StatelessWidget {
  const ToneSetCard(this.set, {super.key, this.marked});

  final ToneSet set;

  /// A word to pick out, on that word's own page.
  final Entry? marked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ToneSetScreen(set))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              for (final t in [1, 2, 3, 4])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _ToneTile(set.byTone[t], t, marked: marked != null && set.byTone[t]?.id == marked!.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToneTile extends StatelessWidget {
  const _ToneTile(this.entry, this.tone, {this.marked = false});

  final Entry? entry;
  final int tone;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = toneColor(tone, theme.brightness);
    final e = entry;
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: e == null ? null : c.withValues(alpha: marked ? 0.28 : 0.1),
        border: Border.all(color: e == null ? theme.dividerColor : c.withValues(alpha: marked ? 1 : 0.4), width: marked ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: e == null
          ? Center(child: Text('—', style: theme.textTheme.bodySmall))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.simplified, style: theme.textTheme.headlineSmall?.copyWith(color: c)),
                Text(e.pinyin, style: theme.textTheme.bodyMedium?.copyWith(color: c, fontWeight: FontWeight.w600)),
                Text(
                  shortMeaning(e),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard(this.rule);
  final ToneRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rule.note, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in rule.words)
                  ActionChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.simplified, style: theme.textTheme.titleMedium),
                        Text('${e.pinyin} → ${e.spoken ?? e.pinyin}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(e))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One tone set: each word big, in its tone colour, to play, star or open.
class ToneSetScreen extends StatefulWidget {
  const ToneSetScreen(this.set, {super.key});

  final ToneSet set;

  @override
  State<ToneSetScreen> createState() => _ToneSetScreenState();
}

class _ToneSetScreenState extends State<ToneSetScreen> {
  bool _playing = false;

  Future<void> _playAll() async {
    final scope = AppScope.of(context);
    setState(() => _playing = true);
    for (final e in widget.set.words) {
      if (!mounted || !_playing) break;
      await scope.speaker.play(e, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final words = widget.set.words;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final allStarred = words.every((e) => store.isStarred(e.id));
        return Scaffold(
          appBar: AppBar(title: Text('${widget.set.syllable} in ${words.length} tones')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text('Same sound, different tone, different word. Listen to them one after another.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                    label: Text(_playing ? 'Stop' : 'Play in order'),
                    onPressed: _playing ? () => setState(() => _playing = false) : _playAll,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.hearing),
                    label: const Text('Practise'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ToneQuizScreen(only: widget.set))),
                  ),
                  OutlinedButton.icon(
                    icon: Icon(allStarred ? Icons.star : Icons.star_border),
                    label: Text(allStarred ? 'All starred' : 'Star all'),
                    onPressed: allStarred
                        ? null
                        : () async {
                            for (final e in words) {
                              if (!store.isStarred(e.id)) await store.toggleStar(e.id);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final e in words) _bigCard(context, e),
              const SizedBox(height: 16),
              Text('Tone sets always show all their words, whatever levels are switched on.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(soundsSourceNote, style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  Widget _bigCard(BuildContext context, Entry e) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final tone = e.syllables.first.tone;
    final c = toneColor(tone, theme.brightness);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c, width: 1.5)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(e))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              SizedBox(width: 64, child: Text(e.simplified, style: theme.textTheme.displaySmall?.copyWith(color: c))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.pinyin, style: theme.textTheme.titleLarge?.copyWith(color: c, fontWeight: FontWeight.w600)),
                    Text(e.syllables.first.toneName, style: theme.textTheme.bodySmall?.copyWith(color: c)),
                    Text(e.gloss, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Play',
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () => scope.speaker.play(e, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
              ),
              StarButton(e),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hear it, pick the tone": a word is played, and the choices are the words
/// of its tone set, shown by pinyin until answered.
class ToneQuizScreen extends StatefulWidget {
  const ToneQuizScreen({super.key, this.only, this.random});

  /// Practise one set only.
  final ToneSet? only;
  final Random? random;

  @override
  State<ToneQuizScreen> createState() => _ToneQuizScreenState();
}

class _ToneQuizScreenState extends State<ToneQuizScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<ToneQuestion>? _queue;
  int _done = 0, _right = 0;
  Entry? _picked;
  DateTime _shownAt = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final scope = AppScope.of(context);
    final size = scope.store.sessionSize;
    _queue = toneQuestions(scope.library, _rnd,
        count: widget.only != null ? 8 : (size == 0 ? 20 : size), only: widget.only, starred: scope.store.starred.toSet());
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play([Entry? e]) {
    final q = _queue!;
    if (q.isEmpty || !mounted) return;
    final scope = AppScope.of(context);
    scope.speaker.play(e ?? q.first.answer, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
  }

  void _pick(Entry e) {
    final q = _queue!.first;
    final now = DateTime.now();
    final right = e.id == q.answer.id;
    AppScope.of(context)
        .store
        .logAnswer(right ? Rating.good : Rating.again, now.difference(_shownAt), now, method: 'tones', id: q.answer.id);
    setState(() {
      _picked = e;
      _done++;
      if (right) _right++;
    });
  }

  void _next() {
    setState(() {
      _queue!.removeAt(0);
      _picked = null;
      _shownAt = DateTime.now();
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue!;
    final dark = theme.brightness == Brightness.dark;
    final good = dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6);
    final bad = dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6);
    final answered = _picked != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Hear it, pick the tone')),
      body: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _done == 0 ? 'No tone sets to practise yet.' : 'All done: $_right of $_done right.',
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
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Which one did you hear?', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Center(
                          child: IconButton.filledTonal(
                            iconSize: 48,
                            tooltip: 'Play again',
                            icon: const Icon(Icons.volume_up),
                            onPressed: _play,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final e in queue.first.set.words) _option(context, e, queue.first.answer, good, bad),
                        if (answered)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _picked!.id == queue.first.answer.id
                                  ? 'Right: ${queue.first.answer.simplified} ${queue.first.answer.pinyin}, ${shortMeaning(queue.first.answer)}.'
                                  : 'It was ${queue.first.answer.simplified} ${queue.first.answer.pinyin}, ${shortMeaning(queue.first.answer)}. '
                                      'Tap each to hear the difference.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (answered)
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

  Widget _option(BuildContext context, Entry e, Entry answer, Color good, Color bad) {
    final theme = Theme.of(context);
    final c = toneColor(e.syllables.first.tone, theme.brightness);
    final answered = _picked != null;
    return Card(
      color: !answered
          ? null
          : e.id == answer.id
              ? good
              : e.id == _picked!.id
                  ? bad
                  : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: answered
            ? Text(e.simplified, style: theme.textTheme.headlineMedium?.copyWith(color: c))
            : null,
        title: Text(e.pinyin, style: theme.textTheme.headlineSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
        subtitle: answered ? Text(shortMeaning(e)) : Text(e.syllables.first.toneName),
        trailing: answered
            ? (e.id == answer.id ? const Icon(Icons.check) : const Icon(Icons.volume_up_outlined))
            : null,
        onTap: answered ? () => _play(e) : () => _pick(e),
      ),
    );
  }
}
