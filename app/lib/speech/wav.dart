import 'dart:typed_data';

/// Audio as samples between -1 and 1.
class Samples {
  const Samples(this.data, this.sampleRate);
  final Float32List data;
  final int sampleRate;

  double get seconds => data.length / sampleRate;
}

/// Reads a 16-bit PCM WAV file (what the recorder writes). Stereo is mixed
/// down to one channel.
Samples readWav(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }
  var channels = 1, rate = 16000, bits = 16;
  var pos = 12;
  while (pos + 8 <= bytes.length) {
    final id = tag(pos);
    var size = b.getUint32(pos + 4, Endian.little);
    final start = pos + 8;
    if (id == 'fmt ') {
      channels = b.getUint16(start + 2, Endian.little);
      rate = b.getUint32(start + 4, Endian.little);
      bits = b.getUint16(start + 14, Endian.little);
    } else if (id == 'data') {
      if (bits != 16) throw FormatException('Expected 16-bit audio, got $bits-bit');
      // A recorder stopped early can leave the size unset or too big.
      if (size == 0 || start + size > bytes.length) size = bytes.length - start;
      final frames = size ~/ (2 * channels);
      final out = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        var sum = 0;
        for (var c = 0; c < channels; c++) {
          sum += b.getInt16(start + (i * channels + c) * 2, Endian.little);
        }
        out[i] = sum / channels / 32768;
      }
      return Samples(out, rate);
    }
    pos = start + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV file has no audio data');
}

/// The same audio at 16 kHz, which the recogniser and pitch tracker expect.
Samples to16k(Samples s) {
  if (s.sampleRate == 16000) return s;
  final ratio = s.sampleRate / 16000;
  final n = (s.data.length / ratio).floor();
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final x = i * ratio;
    final j = x.floor();
    final f = x - j;
    final a = s.data[j];
    final c = j + 1 < s.data.length ? s.data[j + 1] : a;
    out[i] = a + (c - a) * f;
  }
  return Samples(out, 16000);
}
