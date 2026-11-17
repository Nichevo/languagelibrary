import 'dart:async';

import 'package:flutter/material.dart';

import '../data/conversations.dart';
import '../models/entry.dart';
import '../speech/heard.dart';
import '../speech/speech_service.dart';
import '../speech/tone_shape.dart';
import 'common.dart';
import 'say_it_screen.dart';
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
    final conv = AppScope.of(context).library.conversations;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: Readable(
        child: ListView(
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
                  title: Text(s.title),
                  subtitle: Text('${conv.line(s.lines.first)?.simplified ?? ''}\n'
                      '${s.lines.length} lines · HSK ${s.hsk}'),
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
    );
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

  // For the end of the scene.
  int _turns = 0, _firstTime = 0, _saidWell = 0, _spoken = 0;
  bool _missedThisTurn = false;

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
    _missedThisTurn = false;
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
      _missedThisTurn = true;
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
    // Your opening line as the first speaker isn't a choice, so it isn't counted.
    if (_choices.length > 1) {
      _turns++;
      if (!_missedThisTurn) _firstTime++;
    }
    if (!widget.chooseOnly && _tries > 0) {
      _spoken++;
      if (_check?.allRight ?? false) _saidWell++;
    }
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

  void _finish() {
    _phase = _Phase.done;
    _turn = null;
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
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

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return Scaffold(
      appBar: AppBar(title: Text(scene.title, overflow: TextOverflow.ellipsis)),
      body: Readable(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            for (final s in _said) _Bubble(s, onPlay: () => _play(s.entry, female: !s.mine)),
            if (_phase == _Phase.choosing && _turn != null) ..._choosing(context),
            if (_phase == _Phase.saying && _picked != null) ..._saying(context),
            if (_phase == _Phase.done) _Done(
              turns: _turns,
              firstTime: _firstTime,
              saidWell: _saidWell,
              spoken: _spoken,
              chooseOnly: widget.chooseOnly,
              onAgain: () => setState(() {
                _said.clear();
                _turns = _firstTime = _saidWell = _spoken = 0;
                _start();
              }),
            ),
          ],
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
  const _Bubble(this.said, {required this.onPlay});
  final _Said said;
  final VoidCallback onPlay;

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
                  _English(said.entry.meanings.first),
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
  const _English(this.text);
  final String text;

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
              onPressed: () => setState(() => _shown = true),
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

/// A short summary for now; the full review comes in the next step.
class _Done extends StatelessWidget {
  const _Done(
      {required this.turns,
      required this.firstTime,
      required this.saidWell,
      required this.spoken,
      required this.chooseOnly,
      required this.onAgain});
  final int turns, firstTime, saidWell, spoken;
  final bool chooseOnly;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End of the conversation', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (turns > 0) Text('Right reply first time: $firstTime of $turns'),
            if (!chooseOnly && spoken > 0) Text('Said well: $saidWell of $spoken'),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(onPressed: onAgain, child: const Text('Again')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ]),
          ],
        ),
      ),
    );
  }
}
