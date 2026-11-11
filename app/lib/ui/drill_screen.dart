import 'dart:math';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/entry.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'scales_screen.dart';
import 'wide.dart';

/// Multiple choice (see [Choice]) and typing (see a word, type its pinyin).
/// Answers count towards the statistics but don't change when flashcards come back.
enum Drill { listen, type }

/// Kinds of multiple-choice question.
enum Choice {
  listen('Hear it, pick the word', 'Which word did you hear?'),
  meaning('See it, pick the meaning', 'What does it mean?'),
  reverse('See the meaning, pick the word', 'Which word means this?'),
  pinyin('See it, pick the pinyin', 'How is it said?'),

  /// Only in the mix, and only for a word on a scale (see [scaleToOrder]).
  order('Put a scale in order', 'Put them in order');

  const Choice(this.label, this.question);
  final String label;
  final String question;

  /// The setting's value, or null for 'mix'.
  static Choice? fromSetting(String v) => v == 'order' ? null : values.asNameMap()[v];

  /// The kinds that can be picked on their own in Settings.
  static List<Choice> get pickable => [for (final c in values) if (c != order) c];
}

/// A scale [target] is on with at least three words, for a "put in order"
/// question, or null.
(Scale, List<ScaleItem>)? scaleToOrder(Library library, Entry target) {
  for (final s in library.scalesFor(target)) {
    final items = s.items;
    if (items.length >= 3 && items.any((i) => i.entry.id == target.id)) return (s, items);
  }
  return null;
}

/// Removes spaces, apostrophes and punctuation, and writes v as ü.
String normalizePinyin(String s) =>
    s.toLowerCase().replaceAll('v', 'ü').replaceAll('u:', 'ü').replaceAll(RegExp(r"[\s'’\-.,!?，。？！、;:；：]"), '');

enum PinyinCheck { right, wrongTones, wrong }

/// Checks typed pinyin against [e]. Tone marks (nǐ hǎo) or numbers (ni3 hao3)
/// both work; the neutral tone can be typed as 5 or left off.
PinyinCheck checkPinyin(String typed, Entry e) {
  final t = normalizePinyin(typed);
  if (t.isEmpty) return PinyinCheck.wrong;
  final marks = normalizePinyin(e.pinyin);
  final numbers = normalizePinyin(e.pinyinNumbered);
  if (t == marks || t.replaceAll('5', '') == numbers.replaceAll('5', '')) return PinyinCheck.right;
  final toneless = stripTones(t).replaceAll(RegExp('[0-9]'), '');
  if (toneless == stripTones(marks)) return PinyinCheck.wrongTones;
  return PinyinCheck.wrong;
}

/// Up to [count] other words to choose from, none sounding the same as [target]
/// and none with the same meaning.
List<Entry> distractors(Entry target, List<Entry> pool, int count, Random rnd) {
  final sound = stripTones(normalizePinyin(target.pinyin));
  final seen = {sound};
  final glosses = {target.gloss};
  final out = <Entry>[];
  for (final e in [...pool]..shuffle(rnd)) {
    if (out.length == count) break;
    if (e.isSentence || e.id == target.id) continue;
    if (glosses.contains(e.gloss)) continue;
    if (seen.add(stripTones(normalizePinyin(e.pinyin)))) {
      glosses.add(e.gloss);
      out.add(e);
    }
  }
  return out;
}

/// Up to [count] other words for a pinyin question. Real words that sound the
/// same apart from their tones come first (mǎi / mài), so the question is about
/// tones; then words with as many syllables. Every option is a real word's pinyin.
List<Entry> pinyinDistractors(Entry target, List<Entry> pool, int count, Random rnd) {
  final sound = stripTones(normalizePinyin(target.pinyin));
  final marks = {normalizePinyin(target.pinyin)};
  final sameSound = <Entry>[], sameLength = <Entry>[];
  for (final e in [...pool]..shuffle(rnd)) {
    if (e.isSentence || e.id == target.id || !marks.add(normalizePinyin(e.pinyin))) continue;
    if (stripTones(normalizePinyin(e.pinyin)) == sound) {
      sameSound.add(e);
    } else if (e.syllables.length == target.syllables.length) {
      sameLength.add(e);
    }
  }
  return [...sameSound, ...sameLength].take(count).toList();
}

class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key, required this.drill, this.list, this.random});

  final Drill drill;

  /// Custom list, or null for all starred words.
  final String? list;
  final Random? random;

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  late final Random _rnd = widget.random ?? Random();
  List<Entry>? _queue;
  List<Entry> _options = const [];
  int _done = 0, _right = 0;
  DateTime _shownAt = DateTime.now();

  // Listening: the option picked. Typing: the result of checking.
  Entry? _picked;
  Choice _kind = Choice.listen;
  PinyinCheck? _checked;
  (Scale, List<ScaleItem>)? _scale;
  bool _ordered = false;
  final _typed = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final scope = AppScope.of(context);
    final words = [
      for (final id in scope.store.idsIn(widget.list))
        if (scope.library.byId[id] case final e? when !e.isSentence) e,
    ]..shuffle(_rnd);
    final size = scope.store.sessionSize;
    _queue = size > 0 && words.length > size ? words.sublist(0, size) : words;
    _next(first: true);
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _next({bool first = false}) {
    final scope = AppScope.of(context);
    if (!first) _queue!.removeAt(0);
    _picked = null;
    _checked = null;
    _scale = null;
    _ordered = false;
    _typed.clear();
    _shownAt = DateTime.now();
    if (_queue!.isEmpty) return;
    final target = _queue!.first;
    if (widget.drill == Drill.listen) {
      final scale = scaleToOrder(scope.library, target);
      final kinds = [...Choice.pickable, if (scale != null) Choice.order];
      _kind = Choice.fromSetting(scope.store.choiceKind) ?? kinds[_rnd.nextInt(kinds.length)];
      if (_kind == Choice.order) {
        _scale = scale;
        return;
      }
      final shown = scope.library.entries.where(scope.store.shows).toList();
      if (_kind == Choice.pinyin) {
        _options = [target, ...pinyinDistractors(target, shown, 3, _rnd)]..shuffle(_rnd);
      } else {
        // Other words from the same list first, then from the library.
        final own = [for (final id in scope.store.idsIn(widget.list)) ?scope.library.byId[id]];
        var others = distractors(target, own, 3, _rnd);
        if (others.length < 3) {
          final taken = {for (final o in others) o.id};
          others = [
            ...others,
            ...distractors(target, [for (final e in shown) if (!taken.contains(e.id)) e], 3 - others.length, _rnd)
          ];
        }
        _options = [target, ...others]..shuffle(_rnd);
      }
      if (_kind == Choice.listen) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  void _play({bool? slow}) {
    if (!mounted || _queue!.isEmpty) return;
    final scope = AppScope.of(context);
    scope.speaker.play(_queue!.first, female: scope.store.femaleVoice, slow: slow ?? scope.store.slowAudio);
  }

  void _answer(bool right) {
    final now = DateTime.now();
    AppScope.of(context).store.logAnswer(right ? Rating.good : Rating.again, now.difference(_shownAt), now,
        method: widget.drill == Drill.type ? 'type' : _kind.name, id: _queue!.first.id);
    _done++;
    if (right) _right++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue!;
    final title = widget.drill == Drill.listen ? 'Multiple choice' : 'Type the pinyin';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Readable(child: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _done == 0 ? 'Nothing to practise yet. Star some words first.' : 'All done: $_right of $_done right.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: widget.drill == Drill.listen ? _listen(context, queue.first) : _type(context, queue.first),
              ),
            )),
    );
  }

  Widget _counter(BuildContext context) =>
      Text('${_queue!.length} left · $_right of $_done right', style: Theme.of(context).textTheme.bodySmall);

  Widget _nextButton() => SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: () => setState(_next), child: const Text('Next')),
      );

  Widget _order(BuildContext context, Entry target) {
    final (scale, items) = _scale!;
    return Column(
      children: [
        _counter(context),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              OrderQuestion(
                key: ValueKey(target.id),
                scale: scale,
                items: items,
                random: _rnd,
                onChecked: (right) => setState(() {
                  _ordered = true;
                  _answer(right);
                }),
              ),
            ],
          ),
        ),
        if (_ordered) _nextButton(),
      ],
    );
  }

  Widget _listen(BuildContext context, Entry target) {
    final theme = Theme.of(context);
    if (_kind == Choice.order) return _order(context, target);
    final answered = _picked != null;
    final audio = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: _kind == Choice.listen ? 48 : 28,
          tooltip: 'Play again',
          icon: const Icon(Icons.volume_up),
          onPressed: _play,
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          icon: const Icon(Icons.slow_motion_video),
          label: const Text('Slow'),
          onPressed: () => _play(slow: true),
        ),
      ],
    );
    final prompt = switch (_kind) {
      Choice.listen => audio,
      Choice.meaning || Choice.pinyin => Column(children: [
          HanziText(target,
              style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          if (answered) audio,
        ]),
      Choice.reverse || Choice.order => Column(children: [
          Text(target.gloss, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          if (answered) audio,
        ]),
    };
    Widget optionText(Entry o) => switch (_kind) {
          Choice.listen || Choice.reverse || Choice.order => Text(o.simplified, style: theme.textTheme.headlineSmall),
          Choice.meaning => Text(o.gloss, style: theme.textTheme.titleMedium),
          Choice.pinyin => Text(o.pinyin, style: theme.textTheme.headlineSmall),
        };
    // After answering, every option shows all three so wrong ones teach too.
    String detail(Entry o) => switch (_kind) {
          Choice.listen || Choice.reverse || Choice.order => '${o.pinyin} · ${o.gloss}',
          Choice.meaning => '${o.simplified} · ${o.pinyin}',
          Choice.pinyin => '${o.simplified} · ${o.gloss}',
        };

    return Column(
      children: [
        _counter(context),
        const SizedBox(height: 16),
        prompt,
        const SizedBox(height: 8),
        Text(answered ? (_picked == target ? 'Right!' : 'Not quite') : _kind.question,
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final o in _options)
                Card(
                  color: !answered
                      ? null
                      : o == target
                          ? (theme.brightness == Brightness.dark ? const Color(0xFF244D2A) : const Color(0xFFD4F0D6))
                          : o == _picked
                              ? (theme.brightness == Brightness.dark ? const Color(0xFF5D2B2B) : const Color(0xFFFFDAD6))
                              : null,
                  child: ListTile(
                    title: optionText(o),
                    subtitle: answered ? Text(detail(o)) : null,
                    trailing: answered && o == target ? const Icon(Icons.check) : null,
                    onTap: answered
                        ? null
                        : () {
                            setState(() {
                              _picked = o;
                              _answer(o == target);
                            });
                            if (_kind != Choice.listen) _play();
                          },
                  ),
                ),
            ],
          ),
        ),
        if (answered) _nextButton(),
      ],
    );
  }

  Widget _type(BuildContext context, Entry target) {
    final theme = Theme.of(context);
    final store = AppScope.of(context).store;
    final checked = _checked;
    void check() {
      if (checked != null) return;
      setState(() {
        _checked = checkPinyin(_typed.text, target);
        _answer(_checked == PinyinCheck.right);
      });
      AppScope.of(context).speaker.play(target, female: store.femaleVoice, slow: store.slowAudio);
    }

    return Column(
      children: [
        _counter(context),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              Text(target.simplified, style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(target.gloss, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: _typed,
                autofocus: true,
                enabled: checked == null,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => check(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Pinyin',
                  helperText: 'Tone numbers are fine: ni3 hao3. Use v for ü.',
                ),
              ),
              const SizedBox(height: 16),
              if (checked != null) ...[
                Text(
                  switch (checked) {
                    PinyinCheck.right => 'Right!',
                    PinyinCheck.wrongTones => 'Right sounds, but check the tones:',
                    PinyinCheck.wrong => 'The answer is:',
                  },
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                PinyinText(target, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                if (target.spoken != null && target.spoken != target.pinyin)
                  Text('Said as ${target.spoken}', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        if (checked == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: check, child: const Text('Check')),
          )
        else
          _nextButton(),
      ],
    );
  }
}
