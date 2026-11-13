import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/say_it.dart';
import '../srs/scheduler.dart';
import '../models/entry.dart';
import '../speech/feedback.dart';
import '../speech/heard.dart';
import '../speech/speech_service.dart';
import '../speech/tone_shape.dart';
import 'common.dart';
import 'say_it_words_screen.dart';
import 'wide.dart';

/// Shown under every result: where the checks come from.
const sayItSourceNote = 'Checked on this device by an open speech recogniser (sherpa-onnx). '
    'Readings of what it heard from CC-CEDICT. A guide, not a teacher.';

/// "Say it": hear a word, say it, and see what the recogniser heard and what
/// your pitch did.
class SayItScreen extends StatefulWidget {
  const SayItScreen({super.key, this.entries, this.sentences = false, this.recorder, this.checker, this.random});

  /// Practise these. Otherwise a round is picked (see [sayItQueue]).
  final List<Entry>? entries;
  final bool sentences;
  final Recorder? recorder;
  final SpeechChecker? checker;
  final Random? random;

  @override
  State<SayItScreen> createState() => _SayItScreenState();
}

enum _Phase { ready, recording, checking, result }

class _SayItScreenState extends State<SayItScreen> {
  late final Recorder _recorder = widget.recorder ?? MicRecorder();
  late final SpeechChecker _checker = widget.checker ?? OnDeviceChecker.instance;
  final AudioPlayer _player = AudioPlayer();

  late bool _sentences = widget.sentences;
  List<Entry>? _queue;
  int _at = 0, _right = 0;
  _Phase _phase = _Phase.ready;
  DateTime _shownAt = DateTime.now();
  DateTime? _pressedAt;
  Timer? _limit;
  String? _error, _recording;
  WordCheck? _check;
  PitchPicture? _pitch;
  List<double>? _times;
  String? _tryNote;
  final Set<int> _logged = {};

  Entry? get _entry => _queue == null || _at >= _queue!.length ? null : _queue![_at];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queue ??= _pick();
  }

  List<Entry> _pick() {
    if (widget.entries != null) return widget.entries!;
    final scope = AppScope.of(context);
    final size = scope.store.sessionSize;
    return sayItQueue(scope.library, scope.store, widget.random ?? Random(),
        sentences: _sentences, count: size == 0 ? 20 : size);
  }

  @override
  void dispose() {
    _limit?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _listen() {
    final scope = AppScope.of(context);
    scope.speaker.play(_entry!, female: scope.store.femaleVoice, slow: scope.store.slowAudio);
  }

  Future<void> _startRecording() async {
    if (_phase == _Phase.recording || _phase == _Phase.checking) return;
    _pressedAt = DateTime.now();
    if (!await _recorder.allowed()) {
      setState(() => _error = 'The app needs the microphone for this. You can allow it in your device\'s settings.');
      return;
    }
    await _player.stop();
    await _recorder.start();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.recording;
      _error = null;
    });
    // Long enough for any phrasebook sentence.
    _limit = Timer(Duration(seconds: _entry!.isSentence ? 12 : 6), _stopRecording);
  }

  Future<void> _stopRecording() async {
    _limit?.cancel();
    if (_phase != _Phase.recording) return;
    final path = await _recorder.stop();
    final held = DateTime.now().difference(_pressedAt ?? DateTime.now());
    if (!mounted) return;
    if (path == null || held < const Duration(milliseconds: 400)) {
      setState(() {
        _phase = _check == null ? _Phase.ready : _Phase.result;
        _error = 'Hold the button down while you speak, then let go.';
      });
      return;
    }
    setState(() => _phase = _Phase.checking);
    try {
      final result = await _checker.analyse(path);
      final tones = await loadCharTones();
      if (!mounted) return;
      final e = _entry!;
      final check = checkHeard(e, result.transcript.text, tones);
      _log(e, check);
      setState(() {
        _tryNote = _triesSoFar(e, check);
        _recording = path;
        _check = check;
        _pitch = PitchPicture.of(result.pitch);
        _times = result.transcript.charTimes;
        _phase = _Phase.result;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _phase = _check == null ? _Phase.ready : _Phase.result;
        _error = '$err'.replaceFirst('Exception: ', '');
      });
    }
  }

  /// Every try is kept, to work out how many each word takes. The first try
  /// at each word in a round also counts as an answer. A single syllable the
  /// recogniser missed altogether isn't counted against you.
  void _log(Entry e, WordCheck check) {
    if (check.heardNothing && e.syllables.length == 1) return;
    final store = AppScope.of(context).store;
    store.logSpeakTry(e.id, check.allRight, DateTime.now());
    if (_logged.contains(_at)) return;
    _logged.add(_at);
    if (check.allRight) _right++;
    final now = DateTime.now();
    AppScope.of(context)
        .store
        .logAnswer(check.allRight ? Rating.good : Rating.again, now.difference(_shownAt), now, method: 'speak', id: e.id);
  }

  /// "Got it in 3 tries", from every try at this word so far.
  String? _triesSoFar(Entry e, WordCheck check) {
    final store = AppScope.of(context).store;
    final r = speakRecords([for (final t in store.speakTries) if (t.id == e.id) t])[e.id];
    if (r == null) return null;
    if (check.allRight && r.rounds.isNotEmpty) {
      final n = r.rounds.last;
      return n == 1 ? 'First try!' : 'Got it in $n tries';
    }
    return r.open == 1 ? 'Try 1 at this one' : 'Try ${r.open} at this one so far';
  }

  void _openWord(Entry word) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SayItScreen(entries: [word])));

  void _next() {
    _player.stop();
    setState(() {
      _at++;
      _phase = _Phase.ready;
      _check = null;
      _pitch = null;
      _times = null;
      _tryNote = null;
      _recording = null;
      _error = null;
      _shownAt = DateTime.now();
    });
  }

  void _switchKind(bool sentences) {
    setState(() {
      _sentences = sentences;
      _queue = _pick();
      _at = 0;
      _right = 0;
      _logged.clear();
      _phase = _Phase.ready;
      _check = null;
      _pitch = null;
      _error = null;
      _shownAt = DateTime.now();
    });
  }

  Future<void> _playMine() async {
    final path = _recording;
    if (path == null) return;
    await AppScope.of(context).speaker.stop();
    await _player.setFilePath(path);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue!;
    final e = _entry;
    final single = widget.entries != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Say it'),
        actions: [
          if (!single)
            IconButton(
              tooltip: 'Your words',
              icon: const Icon(Icons.leaderboard_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SayItWordsScreen())),
            ),
          if (e != null && queue.length > 1)
            Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('${_at + 1} / ${queue.length}'))),
        ],
        bottom: single
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Words')),
                      ButtonSegment(value: true, label: Text('Sentences')),
                    ],
                    selected: {_sentences},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _switchKind(s.single),
                  ),
                ),
              ),
      ),
      body: Readable(
        child: e == null
            ? _Done(right: _right, total: _logged.length, empty: queue.isEmpty, onAgain: () => _switchKind(_sentences))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _Prompt(e),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                          icon: const Icon(Icons.volume_up), label: const Text('Listen'), onPressed: _listen),
                      OutlinedButton.icon(
                          icon: const Icon(Icons.person),
                          label: const Text('Play mine'),
                          onPressed: _recording == null ? null : _playMine),
                      if (!single || _at < queue.length - 1)
                        _check == null
                            ? OutlinedButton.icon(
                                icon: const Icon(Icons.skip_next), label: const Text('Skip'), onPressed: _next)
                            : FilledButton.icon(
                                icon: const Icon(Icons.arrow_forward), label: const Text('Next'), onPressed: _next),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _MicButton(
                    phase: _phase,
                    onDown: _startRecording,
                    onUp: _stopRecording,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (_phase) {
                      _Phase.recording => 'Listening… let go when you\'re done',
                      _Phase.checking => 'Checking…',
                      _ => 'Hold to speak, let go to check',
                    },
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_check != null) ...[
                    const SizedBox(height: 16),
                    SayItResult(
                      entry: e,
                      check: _check!,
                      pitch: _pitch,
                      charTimes: _times,
                      tryNote: _tryNote,
                      onWord: _openWord,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.entry);
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        HanziText(entry,
            textAlign: TextAlign.center,
            style: (entry.isSentence ? theme.textTheme.headlineMedium : theme.textTheme.displayMedium)
                ?.copyWith(fontWeight: FontWeight.w600)),
        PinyinText(entry, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        if (entry.spoken != null)
          Text('said ${entry.spoken}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(entry.gloss, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.phase, required this.onDown, required this.onUp});
  final _Phase phase;
  final VoidCallback onDown, onUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recording = phase == _Phase.recording;
    return Center(
      child: Listener(
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Semantics(
          button: true,
          label: 'Hold to speak',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: recording ? 96 : 84,
            height: recording ? 96 : 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? scheme.error : scheme.primary,
            ),
            child: phase == _Phase.checking
                ? Padding(padding: const EdgeInsets.all(26), child: CircularProgressIndicator(color: scheme.onPrimary))
                : Icon(Icons.mic, size: 38, color: recording ? scheme.onError : scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// What the recogniser heard and the pitch line, for one try.
class SayItResult extends StatelessWidget {
  const SayItResult(
      {super.key, required this.entry, required this.check, this.pitch, this.charTimes, this.tryNote, this.onWord});
  final Entry entry;
  final WordCheck check;
  final PitchPicture? pitch;
  final List<double>? charTimes;

  /// "Got it in 3 tries".
  final String? tryNote;

  /// Practise one word of a sentence on its own.
  final void Function(Entry word)? onWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final verdict = verdictOf(check);
    final good = verdict == Verdict.matched;
    final lines = problems(check);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHAT THE RECOGNISER HEARD', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(good ? Icons.check_circle : (verdict == Verdict.nothing ? Icons.hearing_disabled : Icons.error),
                        color: good ? Colors.green.shade600 : (verdict == Verdict.nothing ? scheme.outline : scheme.error)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(headline(entry, check), style: theme.textTheme.titleMedium)),
                    if (tryNote != null) Text(tryNote!, style: theme.textTheme.labelMedium),
                  ],
                ),
                if (!check.heardNothing) ...[
                  const SizedBox(height: 10),
                  _Syllables(check),
                ],
                for (final l in lines) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l)),
                const SizedBox(height: 8),
                Text(caveat(entry, check), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (entry.isSentence && onWord != null) _SentenceWords(entry: entry, check: check, onWord: onWord!),
        if (pitch != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR PITCH', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  _ToneTargets(entry),
                  const SizedBox(height: 6),
                  PitchChart(picture: pitch!, entry: entry, charTimes: charTimes),
                  const SizedBox(height: 6),
                  Text(
                    pitch!.isEmpty
                        ? 'No voice was picked up clearly enough to draw.'
                        : 'How your voice rose and fell, against your own middle pitch (dashed). '
                            'The shapes above are each tone\'s textbook shape, after tone changes. '
                            'This is a picture to compare, not a score.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(sayItSourceNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
      ],
    );
  }
}

/// The words of a sentence, to practise one on its own. Words the recogniser
/// got wrong come first and are marked.
class _SentenceWords extends StatelessWidget {
  const _SentenceWords({required this.entry, required this.check, required this.onWord});
  final Entry entry;
  final WordCheck check;
  final void Function(Entry) onWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final words = wordsIn(entry, AppScope.of(context).library);
    if (words.isEmpty) return const SizedBox.shrink();
    final sylAt = syllableAt(entry);
    final wrongSyl = {
      for (final s in check.syllables)
        if (s.heard != Heard.right) entry.syllables.indexOf(s.syllable),
    };
    bool missed(int at, Entry w) =>
        [for (var k = at; k < at + w.simplified.length; k++) sylAt[k]].any(wrongSyl.contains);
    final sorted = [
      for (final (at, w) in words) if (missed(at, w)) (w, true),
      for (final (at, w) in words) if (!missed(at, w)) (w, false),
    ];
    final seen = <String>{};
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRACTISE ONE WORD', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (w, bad) in sorted)
                if (seen.add(w.id))
                  ActionChip(
                    avatar: Icon(Icons.mic_none, size: 18, color: bad ? scheme.onErrorContainer : null),
                    backgroundColor: bad ? scheme.errorContainer : null,
                    label: Text('${w.simplified} ${w.pinyin}',
                        style: bad ? TextStyle(color: scheme.onErrorContainer) : null),
                    onPressed: () => onWord(w),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Each expected character, marked by how it came out.
class _Syllables extends StatelessWidget {
  const _Syllables(this.check);
  final WordCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in check.syllables)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: s.heard == Heard.right ? scheme.surfaceContainerHighest : scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(s.syllable.hanzi ?? '', style: theme.textTheme.titleLarge),
                Text(
                  switch (s.heard) {
                    Heard.right => s.syllable.pinyin,
                    Heard.tone => '→ ${s.reading}',
                    Heard.sound => '→ ${s.char}',
                    Heard.missed => 'missed',
                  },
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: s.heard == Heard.right ? null : scheme.onErrorContainer),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The tone each syllable should have, as a small shape in its tone colour.
class _ToneTargets extends StatelessWidget {
  const _ToneTargets(this.entry);
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final s in entry.syllables)
          if (s.pinyin != 'r')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(size: const Size(22, 14), painter: ToneGlyph(s.spokenTone, toneColor(s.spokenTone, b))),
                const SizedBox(width: 3),
                Text(s.pinyin, style: TextStyle(color: toneColor(s.tone, b), fontWeight: FontWeight.w600)),
              ],
            ),
      ],
    );
  }
}

/// A tone's textbook shape: level high, rising, dipping, falling, or a dot.
class ToneGlyph extends CustomPainter {
  ToneGlyph(this.tone, this.color);
  final int tone;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final path = Path();
    switch (tone) {
      case 1:
        path..moveTo(2, 3)..lineTo(w - 2, 3);
      case 2:
        path..moveTo(2, h * 0.6)..lineTo(w - 2, 2);
      case 3:
        path..moveTo(2, h * 0.45)..quadraticBezierTo(w * 0.45, h * 1.25, w - 2, h * 0.3);
      case 4:
        path..moveTo(2, 2)..lineTo(w - 2, h - 2);
      default:
        canvas.drawCircle(Offset(w / 2, h * 0.6), 2.5, p..style = PaintingStyle.fill);
        return;
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(ToneGlyph old) => old.tone != tone || old.color != color;
}

/// The learner's pitch over time, with the characters placed where the
/// recogniser heard them.
class PitchChart extends StatelessWidget {
  const PitchChart({super.key, required this.picture, required this.entry, this.charTimes});
  final PitchPicture picture;
  final Entry entry;
  final List<double>? charTimes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hanzi = [for (final s in entry.syllables) if (s.pinyin != 'r') s];
    return SizedBox(
      height: 140,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PitchPainter(
          picture: picture,
          line: theme.colorScheme.primary,
          grid: theme.colorScheme.outlineVariant,
          text: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
          labels: charTimes != null && charTimes!.length == hanzi.length
              ? [for (var i = 0; i < hanzi.length; i++) (charTimes![i], hanzi[i].hanzi ?? '')]
              : const [],
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter({required this.picture, required this.line, required this.grid, required this.text, required this.labels});
  final PitchPicture picture;
  final Color line, grid;
  final TextStyle text;
  final List<(double, String)> labels;

  static const _range = 9.0; // semitones above and below the middle

  @override
  void paint(Canvas canvas, Size size) {
    const labelRoom = 22.0;
    final h = size.height - labelRoom;
    final span = max(0.3, picture.end - picture.start);
    double x(double t) => (t - picture.start) / span * size.width;
    double y(double st) => h / 2 - st / _range * (h / 2 - 4);

    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, h / 2), Offset(min(dx + 4, size.width), h / 2), dash);
    }
    final p = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final run in picture.lines) {
      if (run.isEmpty) continue;
      final path = Path()..moveTo(x(run.first.$1), y(run.first.$2));
      for (final (t, st) in run.skip(1)) {
        path.lineTo(x(t), y(st));
      }
      canvas.drawPath(path, p);
    }
    for (final (t, label) in labels) {
      final tp = TextPainter(text: TextSpan(text: label, style: text), textDirection: TextDirection.ltr)..layout();
      final cx = x(t).clamp(tp.width / 2, size.width - tp.width / 2);
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) => old.picture != picture || old.line != line || old.labels != labels;
}

class _Done extends StatelessWidget {
  const _Done({required this.right, required this.total, required this.empty, required this.onAgain});
  final int right, total;
  final bool empty;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(empty ? 'Nothing to practise here yet.' : 'Round done', style: theme.textTheme.headlineSmall),
            if (!empty) ...[
              const SizedBox(height: 8),
              Text('The recogniser understood $right of $total.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onAgain, child: const Text('Another round')),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SayItWordsScreen())),
                child: const Text('See your words: easy and struggling'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

