import 'dart:async';

import 'package:flutter/material.dart';

import '../data/conversations.dart';
import '../data/talk.dart';
import '../models/entry.dart';
import '../speech/heard.dart';
import '../speech/speech_service.dart';
import '../speech/tone_shape.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'say_it_screen.dart';
import 'talk_review.dart';
import 'wide.dart';

const conversationSourceNote = 'Conversations from the Chinese Dialogues Podcast by Wen-Hua Teng, COERLL, '
    'The University of Texas at Austin (CC BY 3.0). Each scene was checked in English before it went in.';

/// Practice > Conversations: the checked scenes, and how you want to play them.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, this.recorder, this.checker, this.autoPlay = true});
  final Recorder? recorder;
  final SpeechChecker? checker;
  final bool autoPlay;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _youStart = false, _chooseOnly = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final conv = scope.library.conversations;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: Readable(
        child: ListenableBuilder(
          listenable: scope.store,
          builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('You start the conversation'),
              subtitle: const Text('Play the first speaker instead of answering'),
              value: _youStart,
              onChanged: (v) => setState(() => _youStart = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Just choose, no speaking'),
              subtitle: const Text('Pick the replies without saying them'),
              value: _chooseOnly,
              onChanged: (v) => setState(() => _chooseOnly = v),
            ),
            const Divider(),
            if (conv.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('No conversations yet.')),
            for (final s in conv.scenes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: _SceneMark(runsOf(scope.store.talkRuns, s.id)),
                  title: Text(s.title),
                  subtitle: Text('${conv.line(s.lines.first)?.simplified ?? ''}\n'
                      '${_sceneNote(runsOf(scope.store.talkRuns, s.id), s)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      scene: s,
                      youStart: _youStart,
                      chooseOnly: _chooseOnly,
                      recorder: widget.recorder,
                      checker: widget.checker,
                      autoPlay: widget.autoPlay,
                    ),
                  )),
                ),
              ),
            const SizedBox(height: 8),
            Text(conversationSourceNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        ),
      ),
    );
  }

  /// "New", or how the last go went and whether it's due again.
  static String _sceneNote(List<TalkRun> runs, Scene s) {
    if (runs.isEmpty) return 'New · ${s.lines.length} lines · HSK ${s.hsk}';
    final last = runs.last;
    final parts = <String>[
      if (last.choices.isNotEmpty) 'Last: ${last.firstTime}/${last.choices.length} right',
      if (last.spokenTurns.isNotEmpty) '${last.saidWell}/${last.spokenTurns.length} said well',
      if (!last.finished) 'stopped early',
      if (!reviewDue(last).isAfter(DateTime.now())) 'Review due',
    ];
    return parts.isEmpty ? 'Done ${runs.length}×' : parts.join(' · ');
  }
}

/// A coloured dot for how the last go at a scene went, or an outline when new.
class _SceneMark extends StatelessWidget {
  const _SceneMark(this.runs);
  final List<TalkRun> runs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (runs.isEmpty) {
      return Tooltip(message: 'New', child: Icon(Icons.circle_outlined, size: 18, color: scheme.outline));
    }
    final m = runs.last.mark;
    return Tooltip(message: markLabel(m), child: Icon(Icons.circle, size: 18, color: markColor(m, scheme)));
  }
}

/// One line on screen, said by the app or by you.
class _Said {
  _Said(this.entry, this.mine, {this.note});
  final Entry entry;
  final bool mine;
  final String? note;
}

enum _Phase { choosing, saying, done }

enum _Mic { idle, recording, checking }

/// One scene: the app says a line, you pick a reply, say it, and carry on.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen(
      {super.key,
      required this.scene,
      this.youStart = false,
      this.chooseOnly = false,
      this.recorder,
      this.checker,
      this.autoPlay = true});
  final Scene scene;

  /// You play the first speaker: the scene starts with your line.
  final bool youStart;

  /// Pick replies without saying them.
  final bool chooseOnly;
  final Recorder? recorder;
  final SpeechChecker? checker;
  final bool autoPlay;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late final Recorder _recorder = widget.recorder ?? MicRecorder();
  late final SpeechChecker _checker = widget.checker ?? OnDeviceChecker.instance;
  final _scroll = ScrollController();

  final List<_Said> _said = [];
  _Phase _phase = _Phase.choosing;
  _Mic _mic = _Mic.idle;

  /// The line whose place your reply takes, and the replies offered there.
  String? _turn;
  List<ReplyChoice> _choices = [];
  final Set<int> _ruledOut = {};
  ReplyChoice? _picked;
  String? _wrongNote;

  WordCheck? _check;
  PitchPicture? _pitch;
  List<double>? _times;
  int _tries = 0;
  bool _holding = false, _starting = false;
  DateTime? _pressedAt;
  Timer? _limit;
  String? _error;

  // For the review at the end.
  final List<TalkTurn> _log = [];
  DateTime _startedAt = DateTime.now(), _turnStartedAt = DateTime.now();
  int _wrongPicks = 0, _peeks = 0;
  TalkRun? _run;
  List<TalkRun> _earlier = const [];

  Conversations get _conv => AppScope.of(context).library.conversations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_turn == null && _said.isEmpty) _start();
  }

  @override
  void dispose() {
    _limit?.cancel();
    _recorder.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    final first = widget.scene.lines.first;
    if (widget.youStart) {
      final e = _conv.line(first)!;
      _yourTurn(first, [ReplyChoice(e, true, _conv.next[first])]);
    } else {
      _appSays(first);
    }
  }

  void _play(Entry e, {required bool female}) {
    if (!widget.autoPlay) return;
    final scope = AppScope.of(context);
    unawaited(scope.speaker.play(e, female: female, slow: scope.store.slowAudio).catchError((_) {}));
  }

  /// The app says [lineId] in the female voice, then it's your turn.
  void _appSays(String lineId) {
    final e = _conv.line(lineId);
    if (e == null) return _finish();
    _said.add(_Said(e, false));
    _play(e, female: true);
    final yours = _conv.next[lineId];
    if (yours == null) return _finish();
    final choices = _conv.choices(yours);
    if (choices == null || choices.isEmpty) return _finish();
    _yourTurn(yours, choices);
  }

  void _yourTurn(String lineId, List<ReplyChoice> choices) {
    _turn = lineId;
    _choices = choices;
    _ruledOut.clear();
    _picked = null;
    _wrongNote = null;
    _wrongPicks = 0;
    _turnStartedAt = DateTime.now();
    _resetSpeech();
    _phase = _Phase.choosing;
    // Your very first line as the first speaker: there's nothing to choose.
    if (choices.length == 1) _pick(0);
    _scrollDown();
  }

  void _resetSpeech() {
    _check = null;
    _pitch = null;
    _times = null;
    _tries = 0;
    _error = null;
    _mic = _Mic.idle;
  }

  void _pick(int i) {
    final c = _choices[i];
    if (!c.right) {
      _wrongPicks++;
      _ruledOut.add(i);
      final question = _said.isEmpty ? null : _said.last.entry;
      _wrongNote = 'Good Chinese, but it doesn\'t answer. It says “${c.entry.meanings.first}”'
          '${question == null ? '' : ', and the line was “${question.meanings.first}”'}. Pick another.';
      setState(() {});
      return;
    }
    _picked = c;
    _wrongNote = null;
    if (widget.chooseOnly) {
      // Your first line as the first speaker comes up while the scene is being
      // set up; show it with Carry on rather than skipping straight past it.
      if (_choices.length == 1) {
        _phase = _Phase.saying;
        return;
      }
      _carryOn();
      return;
    }
    _phase = _Phase.saying;
    if (mounted) setState(() {});
    _scrollDown();
  }

  /// The other right reply, shown once you've picked one.
  ReplyChoice? get _alsoRight {
    final p = _picked;
    if (p == null) return null;
    for (final c in _choices) {
      if (c.right && c != p) return c;
    }
    return null;
  }

  void _carryOn() {
    final p = _picked!;
    _logTurn(p);
    final note = widget.chooseOnly
        ? null
        : _tries == 0
            ? 'not said'
            : (_check?.allRight ?? false)
                ? (_tries == 1 ? 'said well first try' : 'said well on try $_tries')
                : 'tried $_tries ${_tries == 1 ? 'time' : 'times'}';
    _said.add(_Said(p.entry, true, note: note));
    _turn = null;
    final then = p.then;
    if (then == null) {
      _finish();
    } else {
      _appSays(then);
    }
    setState(() {});
    _scrollDown();
  }

  /// Keeps what happened at this turn, and counts the reply toward the daily
  /// goal and Progress.
  void _logTurn(ReplyChoice p) {
    final check = _check;
    final choice = _choices.length > 1;
    _log.add(TalkTurn(
      line: _turn ?? '',
      picked: p.entry.id,
      wrongPicks: _wrongPicks,
      tries: _tries,
      saidWell: check?.allRight ?? false,
      heardRight: check == null ? 0 : check.syllables.where((s) => s.heard == Heard.right).length,
      heardOf: check?.syllables.length ?? 0,
      slips: check == null ? const [] : slipsOf(check),
      choice: choice,
    ));
    // Your opening line as the first speaker isn't a choice, so it isn't counted.
    if (choice) {
      final now = DateTime.now();
      unawaited(AppScope.of(context).store.logAnswer(
          _wrongPicks == 0 ? Rating.good : Rating.again, now.difference(_turnStartedAt), now,
          method: 'talk', id: p.entry.id));
    }
  }

  /// Ends the scene (or stops it early) and shows the review.
  void _finish({bool stopped = false}) {
    _phase = _Phase.done;
    _turn = null;
    final store = AppScope.of(context).store;
    final now = DateTime.now();
    final run = TalkRun(
      at: now,
      scene: widget.scene.id,
      seconds: now.difference(_startedAt).inSeconds,
      finished: !stopped,
      turns: List.of(_log),
      youStart: widget.youStart,
      chooseOnly: widget.chooseOnly,
      englishPeeks: _peeks,
    );
    _earlier = runsOf(store.talkRuns, widget.scene.id);
    _run = run;
    if (run.turns.isNotEmpty) unawaited(store.logTalkRun(run));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _again() => setState(() {
        _said.clear();
        _log.clear();
        _peeks = 0;
        _run = null;
        _startedAt = DateTime.now();
        _start();
      });

  /// Asked when you leave in the middle of a scene with turns done.
  Future<void> _askStop() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop this scene?'),
        content: const Text('You\'ll see how it went so far.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Stop and review')),
        ],
      ),
    );
    if (stop == true && mounted) setState(() => _finish(stopped: true));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _phase != _Phase.done) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  static const _holdHint = 'Hold the button down while you speak, then let go.';

  Future<void> _startRecording() async {
    if (_mic != _Mic.idle || _starting) return;
    _holding = true;
    _starting = true;
    try {
      _pressedAt = DateTime.now();
      if (!await _recorder.allowed()) {
        if (mounted) {
          setState(() => _error = 'The app needs the microphone for this. You can allow it in your device\'s settings.');
        }
        return;
      }
      if (!_holding || !mounted) {
        if (mounted) setState(() => _error = _holdHint);
        return;
      }
      await AppScope.of(context).speaker.stop().catchError((_) {});
      await _recorder.start();
    } finally {
      _starting = false;
    }
    if (!mounted) return;
    if (!_holding) {
      await _recorder.stop();
      if (mounted) setState(() => _error = _holdHint);
      return;
    }
    setState(() {
      _mic = _Mic.recording;
      _error = null;
    });
    _limit = Timer(const Duration(seconds: 12), _stopRecording);
  }

  Future<void> _stopRecording() async {
    _holding = false;
    _limit?.cancel();
    if (_mic != _Mic.recording) return;
    final path = await _recorder.stop();
    final held = DateTime.now().difference(_pressedAt ?? DateTime.now());
    if (!mounted) return;
    if (path == null || held < const Duration(milliseconds: 400)) {
      setState(() {
        _mic = _Mic.idle;
        _error = _holdHint;
      });
      return;
    }
    setState(() => _mic = _Mic.checking);
    try {
      final result = await _checker.analyse(path);
      final tones = await loadCharTones();
      if (!mounted) return;
      final check = checkHeard(_picked!.entry, result.transcript.text, tones);
      _logWords(_picked!.entry.id, check);
      setState(() {
        _tries++;
        _check = check;
        _pitch = PitchPicture.of(result.pitch);
        _times = result.transcript.charTimes;
        _mic = _Mic.idle;
      });
      _scrollDown();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _mic = _Mic.idle;
        _error = '$err'.replaceFirst('Exception: ', '');
      });
    }
  }

  /// Each library word in the line counts as a Say it try for that word.
  void _logWords(String entryId, WordCheck check) {
    final store = AppScope.of(context).store;
    final now = DateTime.now();
    var i = 0;
    for (final (hanzi, id) in _conv.words[entryId] ?? const <(String, String?)>[]) {
      final n = _hanCount(hanzi);
      final part = check.syllables.skip(i).take(n).toList();
      i += n;
      if (id == null || part.length < n || n == 0) continue;
      unawaited(store.logSpeakTry(id, part.every((s) => s.heard == Heard.right), now));
    }
  }

  static final _han = RegExp(r'[㐀-鿿]');
  static int _hanCount(String s) => _han.allMatches(s).length;

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final midway = _phase != _Phase.done && _log.isNotEmpty;
    return PopScope(
      canPop: !midway,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askStop();
      },
      child: Scaffold(
      appBar: AppBar(title: Text(scene.title, overflow: TextOverflow.ellipsis), actions: [
        if (midway) TextButton(onPressed: _askStop, child: const Text('Stop')),
      ]),
      body: Readable(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // At the end the review takes the whole screen, so it can't be missed
            // below the conversation.
            if (_phase != _Phase.done)
            for (final s in _said)
              _Bubble(s, onPlay: () => _play(s.entry, female: !s.mine), onEnglish: () => _peeks++),
            if (_phase == _Phase.choosing && _turn != null) ..._choosing(context),
            if (_phase == _Phase.saying && _picked != null) ..._saying(context),
            if (_phase == _Phase.done && _run != null) ...[
              const SizedBox(height: 8),
              Text(_run!.finished ? 'End of the conversation' : 'Stopped early',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              TalkReview(run: _run!, earlier: _earlier, onAgain: _again),
            ],
          ],
        ),
      ),
    ),
    );
  }

  List<Widget> _choosing(BuildContext context) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 8),
      Text('PICK A REPLY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
      const SizedBox(height: 6),
      for (var i = 0; i < _choices.length; i++)
        _ChoiceCard(
          choice: _choices[i],
          ruledOut: _ruledOut.contains(i),
          onTap: _ruledOut.contains(i) ? null : () => _pick(i),
          onPlay: () => _play(_choices[i].entry, female: false),
        ),
      if (_wrongNote != null)
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_wrongNote!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ),
    ];
  }

  List<Widget> _saying(BuildContext context) {
    final theme = Theme.of(context);
    final p = _picked!;
    final also = _alsoRight;
    return [
      const SizedBox(height: 8),
      Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text(_choices.length == 1 ? 'Your line' : 'Good choice', style: theme.textTheme.titleSmall),
              ]),
              const SizedBox(height: 6),
              HanziText(p.entry, style: theme.textTheme.headlineSmall),
              PinyinText(p.entry, style: theme.textTheme.bodyLarge),
              Text(p.entry.meanings.first, style: theme.textTheme.bodyMedium),
              if (also != null) ...[
                const SizedBox(height: 6),
                Text('${also.entry.simplified} (“${also.entry.meanings.first}”) would also have worked.',
                    style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
              icon: const Icon(Icons.volume_up),
              label: const Text('Listen'),
              onPressed: () => _play(p.entry, female: false)),
          widget.chooseOnly
              ? FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward), label: const Text('Carry on'), onPressed: _carryOn)
              : _check == null
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.skip_next), label: const Text('Skip saying it'), onPressed: _carryOn)
              : const SizedBox.shrink(),
        ],
      ),
      if (!widget.chooseOnly) ...[
      const SizedBox(height: 16),
      Center(
        child: Listener(
          onPointerDown: (_) => _startRecording(),
          onPointerUp: (_) => _stopRecording(),
          onPointerCancel: (_) => _stopRecording(),
          child: Semantics(
            button: true,
            label: 'Hold to speak',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _mic == _Mic.recording ? 96 : 84,
              height: _mic == _Mic.recording ? 96 : 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mic == _Mic.recording ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
              child: _mic == _Mic.checking
                  ? Padding(
                      padding: const EdgeInsets.all(26),
                      child: CircularProgressIndicator(color: theme.colorScheme.onPrimary))
                  : Icon(Icons.mic,
                      size: 38,
                      color: _mic == _Mic.recording ? theme.colorScheme.onError : theme.colorScheme.onPrimary),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        switch (_mic) {
          _Mic.recording => 'Listening… let go when you\'re done',
          _Mic.checking => 'Checking…',
          _ => _check == null ? 'Hold to say it, let go to check' : 'Hold to try again, or carry on',
        },
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
        ),
      if (_check != null) ...[
        const SizedBox(height: 16),
        SayItResult(
          entry: p.entry,
          check: _check!,
          pitch: _pitch,
          charTimes: _times,
          tryNote: _tries == 1 ? 'Try 1' : 'Try $_tries',
        ),
        const SizedBox(height: 12),
        // Never blocked: carry on whether or not it was said well.
        Center(
          child: FilledButton.icon(
              icon: const Icon(Icons.arrow_forward), label: const Text('Carry on'), onPressed: _carryOn),
        ),
      ],
      ],
    ];
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.said, {required this.onPlay, required this.onEnglish});
  final _Said said;
  final VoidCallback onPlay, onEnglish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = said.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: onPlay,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HanziText(said.entry, style: theme.textTheme.titleLarge),
                  PinyinText(said.entry, style: theme.textTheme.bodyMedium),
                  _English(said.entry.meanings.first, onShown: onEnglish),
                  if (said.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(said.note!, style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// English stays hidden until tapped, so you have to understand the Chinese.
class _English extends StatefulWidget {
  const _English(this.text, {required this.onShown});
  final String text;
  final VoidCallback onShown;

  @override
  State<_English> createState() => _EnglishState();
}

class _EnglishState extends State<_English> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _shown
        ? Text(widget.text, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
        : Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(36, 28)),
              onPressed: () {
                widget.onShown();
                setState(() => _shown = true);
              },
              child: const Text('EN'),
            ),
          );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.choice, required this.ruledOut, this.onTap, required this.onPlay});
  final ReplyChoice choice;
  final bool ruledOut;
  final VoidCallback? onTap, onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: ruledOut ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ruledOut ? theme.colorScheme.error : theme.colorScheme.outlineVariant),
        ),
        child: ListTile(
          onTap: onTap,
          title: HanziText(choice.entry, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PinyinText(choice.entry),
              if (ruledOut) Text('Doesn\'t fit: ${choice.entry.meanings.first}'),
            ],
          ),
          trailing: IconButton(tooltip: 'Play', icon: const Icon(Icons.volume_up_outlined), onPressed: onPlay),
        ),
      ),
    );
  }
}
