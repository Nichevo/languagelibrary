import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'pitch.dart';
import 'wav.dart';

/// What the recogniser wrote, and when (seconds) it placed each character.
class Transcript {
  const Transcript(this.text, this.charTimes);
  final String text;

  /// One time per Chinese character in [text], or null when the recogniser's
  /// pieces don't line up one per character.
  final List<double>? charTimes;
}

/// The speech recogniser's files: a small Chinese model from the sherpa-onnx
/// project (Apache 2.0), run on the device with no internet.
class ModelFiles {
  const ModelFiles(this.model, this.tokens);
  final String model;
  final String tokens;
}

bool _bound = false;

/// The recogniser, loaded once (loading takes about a second).
class Recognizer {
  /// [libraryPath] is the folder holding the native library, needed only
  /// outside the app (in tests); the app finds its own.
  Recognizer(ModelFiles files, {String? libraryPath}) {
    if (!_bound) {
      sherpa.initBindings(libraryPath);
      _bound = true;
    }
    _r = sherpa.OnlineRecognizer(sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        zipformer2Ctc: sherpa.OnlineZipformer2CtcModelConfig(model: files.model),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
      ),
      enableEndpoint: false,
    ));
  }

  late final sherpa.OnlineRecognizer _r;

  /// Runs over a whole recording.
  Transcript transcribe(Samples input) {
    final s = to16k(input);
    final stream = _r.createStream();
    try {
      // A little silence either side helps with words said right at the edges.
      stream.acceptWaveform(samples: Float32List(3200), sampleRate: 16000);
      stream.acceptWaveform(samples: s.data, sampleRate: 16000);
      stream.acceptWaveform(samples: Float32List(8000), sampleRate: 16000);
      stream.inputFinished();
      while (_r.isReady(stream)) {
        _r.decode(stream);
      }
      final r = _r.getResult(stream);
      final text = r.text.trim();
      final chars = RegExp(r'[\u3400-\u9fff]').allMatches(text).length;
      List<double>? times;
      if (r.tokens.length == chars && r.timestamps.length == chars) {
        times = [for (final t in r.timestamps) t - 0.2];
      }
      return Transcript(text, times);
    } finally {
      stream.free();
    }
  }

  void free() => _r.free();
}

/// Everything the app works out from one recording.
class SpeechResult {
  const SpeechResult(this.transcript, this.pitch);
  final Transcript transcript;
  final PitchTrack pitch;
}

/// Reads a WAV recording, recognises it and tracks its pitch. Slow enough to
/// run off the main thread (see Isolate.run).
SpeechResult analyseWav(Uint8List wav, Recognizer recognizer) {
  final samples = readWav(wav);
  return SpeechResult(recognizer.transcribe(samples), trackPitch(samples));
}

