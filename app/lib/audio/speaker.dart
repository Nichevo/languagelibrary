import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../data/library.dart';
import '../models/entry.dart';

/// Plays an entry: the studio clip if it has been made, otherwise the phone's
/// own Chinese voice (which can't promise a female or male voice).
class Speaker {
  Speaker(this.library);

  final Library library;
  final AudioPlayer _player = AudioPlayer();
  FlutterTts? _tts;

  static const slowSpeed = 0.75;

  bool hasStudioAudio(Entry e) =>
      library.audioFor(e, female: true) != null || library.audioFor(e, female: false) != null;

  Future<void> play(Entry e, {required bool female, bool slow = false}) async {
    final file = library.audioFor(e, female: female) ?? library.audioFor(e, female: !female);
    if (file != null) {
      await _player.stop();
      await _player.setAsset('assets/audio/$file');
      await _player.setSpeed(slow ? slowSpeed : 1.0);
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(slow ? 0.34 : 0.45);
    // So "Play in order" waits for each word before the next.
    await tts.awaitSpeakCompletion(true);
    await tts.speak(e.simplified);
  }

  /// Read any Chinese text with the phone's voice (used for example sentences).
  Future<void> speakText(String text, {bool slow = false}) async {
    await _player.stop();
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(slow ? 0.34 : 0.45);
    await tts.speak(text);
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _tts?.stop();
  }
}
