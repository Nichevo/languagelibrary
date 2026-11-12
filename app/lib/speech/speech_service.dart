import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'heard.dart';
import 'pitch.dart';
import 'recognizer.dart';

/// Records the learner. Swapped for a fake in tests.
abstract class Recorder {
  /// Asks for the microphone if needed. False when it was refused.
  Future<bool> allowed();
  Future<void> start();

  /// Stops and returns the recording as a 16 kHz WAV file, or null.
  Future<String?> stop();
  Future<void> dispose();
}

/// Works out what was said. Swapped for a fake in tests.
abstract class SpeechChecker {
  Future<SpeechResult> analyse(String wavPath);
}

class MicRecorder implements Recorder {
  final AudioRecorder _rec = AudioRecorder();

  @override
  Future<bool> allowed() => _rec.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: '${dir.path}/say_it.wav',
    );
  }

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> dispose() => _rec.dispose();
}

/// The recogniser runs in a background isolate so the screen stays smooth.
/// It is loaded once, on the first check, and kept for the rest of the run.
class OnDeviceChecker implements SpeechChecker {
  OnDeviceChecker._();
  static final OnDeviceChecker instance = OnDeviceChecker._();

  static const _modelAsset = 'assets/speech/model.int8.onnx';
  static const _tokensAsset = 'assets/speech/tokens.txt';

  Future<SendPort>? _starting;

  @override
  Future<SpeechResult> analyse(String wavPath) async {
    final worker = await (_starting ??= _start());
    final reply = ReceivePort();
    worker.send((wavPath, reply.sendPort));
    final answer = await reply.first;
    reply.close();
    if (answer is String) throw Exception(answer);
    final (text, times, hz) = answer as (String, List<double>?, List<double?>);
    return SpeechResult(Transcript(text, times), PitchTrack(hz));
  }

  Future<SendPort> _start() async {
    try {
      final files = await _copyModel();
      final ready = ReceivePort();
      await Isolate.spawn(_run, (ready.sendPort, files.model, files.tokens));
      final first = await ready.first;
      if (first is String) throw Exception(first);
      return first as SendPort;
    } catch (_) {
      _starting = null; // try again next time
      rethrow;
    }
  }

  /// The recogniser reads its model from a file, so it is copied out of the
  /// app's assets once.
  static Future<ModelFiles> _copyModel() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/speech-1');
    await dir.create(recursive: true);
    Future<String> copy(String asset) async {
      final data = await rootBundle.load(asset);
      final f = File('${dir.path}/${asset.split('/').last}');
      if (!await f.exists() || await f.length() != data.lengthInBytes) {
        await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      return f.path;
    }

    return ModelFiles(await copy(_modelAsset), await copy(_tokensAsset));
  }

  static void _run((SendPort, String, String) args) {
    final (ready, model, tokens) = args;
    final Recognizer recognizer;
    try {
      recognizer = Recognizer(ModelFiles(model, tokens));
    } catch (e) {
      ready.send('The speech recogniser could not start: $e');
      return;
    }
    final inbox = ReceivePort();
    ready.send(inbox.sendPort);
    inbox.listen((msg) {
      final (path, reply) = msg as (String, SendPort);
      try {
        final r = analyseWav(File(path).readAsBytesSync(), recognizer);
        reply.send((r.transcript.text, r.transcript.charTimes, r.pitch.hz));
      } catch (e) {
        reply.send('Could not check the recording: $e');
      }
    });
  }
}

/// assets/data/char_tones.tsv, loaded once.
Future<CharTones> loadCharTones() async =>
    _tones ??= CharTones.parse(await rootBundle.loadString('assets/data/char_tones.tsv'));
CharTones? _tones;

