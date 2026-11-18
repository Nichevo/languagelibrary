import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/key_sounds.dart';
import '../models/entry.dart';
import '../speech/pitch_refs.dart';
import '../speech/speech_service.dart';
import '../speech/tone_shape.dart';
import 'common.dart';
import 'key_sounds_screen.dart';
import 'say_it_screen.dart' show PitchChart, sayItSourceNote;
import 'sounds_screen.dart' show shortMeaning;
import 'wide.dart';

/// Say both words of a sound pair, each after hearing it, and compare your
/// pitch line with the clip's. For groups where the recogniser passed the
/// clip test (tools/sound_pairs_report.md), it also says which of the two
/// it heard, or that it couldn't tell.
class SayBothScreen extends StatefulWidget {
  const SayBothScreen({super.key, required this.pair, this.recorder, this.checker});
  final ShownPair pair;
  final Recorder? recorder;
  final SpeechChecker? checker;

  @override
  State<SayBothScreen> createState() => _SayBothScreenState();
}

enum _Phase { ready, recording, checking }

class _Try {
  _Try(this.heard, this.side, this.pitch, this.recording);

  /// Chinese characters the recogniser wrote.
  final String heard;

  /// 'a', 'b' or null (couldn't tell).
  final String? side;
  final PitchPicture? pitch;
  final String? recording;
}

class _SayBothScreenState extends State<SayBothScreen> {
  late final Recorder _recorder = widget.recorder ?? MicRecorder();
  late final SpeechChecker _checker = widget.checker ?? OnDeviceChecker.instance;
  final AudioPlayer _player = AudioPlayer();
  final _tries = <String, _Try>{};
  String? _active;
  _Phase _phase = _Phase.ready;
  bool _holding = false;
  DateTime? _pressedAt;
  Timer? _limit;
  String? _error;
  PitchRefs? _refs;

  @override
  void initState() {
    super.initState();
    PitchRefs.load().then((r) {
      if (mounted) setState(() => _refs = r);
    });
  }

  @override
  void dispose() {
    _limit?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Entry _word(String side) => side == 'a' ? widget.pair.a : widget.pair.b;

  SoundGroup? get _group => AppScope.of(context).library.keySounds.group(groupOf(widget.pair.pair.contrast));

  Future<void> _down(String side) async {
    if (_phase != _Phase.ready) return;
    _holding = true;
    _active = side;
    _pressedAt = DateTime.now();
    if (!await _recorder.allowed()) {
      if (mounted) setState(() => _error = 'The app needs the microphone for this. You can allow it in your device\'s settings.');
      return;
    }
    if (!_holding || !mounted) return;
    await _player.stop();
    await _recorder.start();
    if (!mounted) return;
    if (!_holding) {
      await _recorder.stop();
      return;
    }
    setState(() {
      _phase = _Phase.recording;
      _error = null;
    });
    _limit = Timer(const Duration(seconds: 5), _up);
  }

  Future<void> _up() async {
    _holding = false;
    _limit?.cancel();
    if (_phase != _Phase.recording) return;
    final side = _active!;
    final path = await _recorder.stop();
    final held = DateTime.now().difference(_pressedAt ?? DateTime.now());
    if (!mounted) return;
    if (path == null || held < const Duration(milliseconds: 400)) {
      setState(() {
        _phase = _Phase.ready;
        _error = 'Hold the button down while you speak, then let go.';
      });
      return;
    }
    setState(() => _phase = _Phase.checking);
    try {
      // Each side keeps its own recording, since the recorder reuses one file.
      var mine = path;
      try {
        mine = (await File(path).copy('${path}_$side.wav')).path;
      } on FileSystemException {
        // Keep the shared file; only Play mine is affected.
      }
      final result = await _checker.analyse(mine);
      final tones = await loadCharTones();
      if (!mounted) return;
      final scope = AppScope.of(context);
      final g = _group;
      final text = result.transcript.text;
      final heard = heardSide(text, widget.pair.a.pinyinNumbered, widget.pair.b.pinyinNumbered, g?.kind ?? 'tone', tones.byChar);
      if (g != null && g.heardCheck && heard != null && heard != side) {
        final ch = RegExp(r'[㐀-鿿]').firstMatch(text)?.group(0) ?? '';
        unawaited(scope.store.logSaySlip(SaySlip(DateTime.now(), widget.pair.pair.contrast, _word(side).id, ch)));
      }
      setState(() {
        _tries[side] = _Try(text, heard, PitchPicture.of(result.pitch), mine);
        _phase = _Phase.ready;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _error = '$err'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _playMine(String side) async {
    final path = _tries[side]?.recording;
    if (path == null) return;
    await AppScope.of(context).speaker.stop();
    await _player.setFilePath(path);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = _group;
    return Scaffold(
      appBar: AppBar(title: const Text('Say both')),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hear each word, then hold the mic and say it. The dotted line is the clip, the solid line is you.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final side in ['a', 'b']) _side(context, side, g),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            Text(
              g != null && g.heardCheck
                  ? '"Heard" only says which of the two words it sounded closer to. On our voice clips it was right '
                      'about 98 times in 100 when it could tell. $sayItSourceNote'
                  : 'For tones the recogniser isn\'t reliable enough to say which word it heard, so compare the '
                      'lines yourself. $sayItSourceNote',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(BuildContext context, String side, SoundGroup? g) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final e = _word(side);
    final other = _word(side == 'a' ? 'b' : 'a');
    final t = _tries[side];
    final busy = _active == side && _phase != _Phase.ready;
    final clip = scope.library.audioFor(e, female: scope.store.femaleVoice) ??
        scope.library.audioFor(e, female: !scope.store.femaleVoice);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(e.simplified, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MarkedPinyin(e, other, kind: g?.kind ?? 'tone'),
                  Text(shortMeaning(e), style: theme.textTheme.bodySmall),
                ]),
              ),
              IconButton.filledTonal(
                tooltip: 'Listen',
                icon: const Icon(Icons.volume_up),
                onPressed: () => scope.speaker.play(e, female: scope.store.femaleVoice, slow: scope.store.slowAudio),
              ),
              const SizedBox(width: 6),
              Listener(
                onPointerDown: (_) => _down(side),
                onPointerUp: (_) => _up(),
                onPointerCancel: (_) => _up(),
                child: Semantics(
                  button: true,
                  label: 'Hold to say ${e.simplified}',
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: busy && _phase == _Phase.recording ? theme.colorScheme.error : theme.colorScheme.primary,
                    child: busy && _phase == _Phase.checking
                        ? SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                        : Icon(Icons.mic, color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ]),
            if (t != null) ...[
              const SizedBox(height: 8),
              if (g != null && g.heardCheck) _verdict(context, t, side),
              if (t.pitch != null)
                PitchChart(
                  picture: t.pitch!,
                  entry: e,
                  reference: clip == null ? null : _refs?.lineFor(clip.replaceAll('.mp3', '')),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    icon: const Icon(Icons.person), label: const Text('Play mine'), onPressed: () => _playMine(side)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verdict(BuildContext context, _Try t, String side) {
    final theme = Theme.of(context);
    final (icon, color, text) = switch (t.side) {
      null => (Icons.help_outline, theme.colorScheme.outline,
          t.heard.isEmpty ? 'It didn\'t catch a word. Try again a little louder.' : 'Couldn\'t tell which of the two it heard.'),
      final s when s == side => (Icons.check_circle, Colors.green.shade600, 'Heard ${_word(side).simplified} ${_word(side).pinyin}'),
      _ => (Icons.error, theme.colorScheme.error,
          'Sounded closer to ${_word(t.side!).simplified} ${_word(t.side!).pinyin}. Hear the clip and try again.'),
    };
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Expanded(child: Text(text)),
    ]);
  }
}
