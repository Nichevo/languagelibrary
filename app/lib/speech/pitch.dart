import 'dart:math';
import 'dart:typed_data';

import 'wav.dart';

/// Pitch every 10 ms, found with the YIN method (de Cheveigné and Kawahara,
/// 2002). Null where there is no voice: silence, or sounds like s, sh, x, f.
class PitchTrack {
  PitchTrack(this.hz);

  static const hop = 0.01;

  final List<double?> hz;

  /// The speaker's middle pitch, so tone shapes can be shown in semitones
  /// above or below it whatever the voice's natural height.
  late final double? median = () {
    final v = [for (final f in hz) ?f]..sort();
    return v.isEmpty ? null : v[v.length ~/ 2];
  }();

  /// Semitones from [median] (12 semitones = one octave).
  List<double?> get semitones {
    final m = median;
    return [for (final f in hz) f == null || m == null ? null : 12 * log(f / m) / ln2];
  }
}

const _minHz = 70.0, _maxHz = 450.0, _threshold = 0.35;

PitchTrack trackPitch(Samples input) {
  final s = to16k(input);
  final x = s.data;
  const rate = 16000;
  final tauMin = (rate / _maxHz).floor();
  final tauMax = (rate / _minHz).ceil();
  const window = 400; // 25 ms
  const hop = 160; // 10 ms
  final frames = x.length < window + tauMax ? 0 : (x.length - window - tauMax) ~/ hop + 1;

  // Quiet frames are left out: a tenth of the loudest frame's level.
  final rms = Float64List(frames);
  var loudest = 0.0;
  for (var i = 0; i < frames; i++) {
    var e = 0.0;
    for (var j = 0; j < window; j++) {
      final v = x[i * hop + j];
      e += v * v;
    }
    rms[i] = sqrt(e / window);
    loudest = max(loudest, rms[i]);
  }

  final d = Float64List(tauMax + 1);
  final raw = List<double?>.filled(frames, null);
  for (var i = 0; i < frames; i++) {
    if (rms[i] < loudest * 0.03 || rms[i] < 0.002) continue;
    final o = i * hop;
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var j = 0; j < window; j++) {
        final diff = x[o + j] - x[o + j + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    // Cumulative mean normalised difference.
    var running = 0.0;
    double? best;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      d[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    for (var tau = tauMin; tau < tauMax; tau++) {
      if (d[tau] < _threshold) {
        while (tau + 1 < tauMax && d[tau + 1] < d[tau]) {
          tau++;
        }
        // Parabolic interpolation for a finer period.
        final a = d[tau - 1], b = d[tau], c = d[tau + 1];
        final den = a - 2 * b + c;
        final shift = den == 0 ? 0.0 : 0.5 * (a - c) / den;
        best = rate / (tau + shift.clamp(-1.0, 1.0));
        break;
      }
    }
    raw[i] = best;
  }
  return PitchTrack(_clean(raw));
}

/// Drops octave slips and lone blips, then smooths with a median of five.
/// tools/pitch_refs.py does the same for the app's voice clips: keep in step.
List<double?> _clean(List<double?> raw) {
  final n = raw.length;
  final out = List<double?>.of(raw);
  for (var i = 0; i < n; i++) {
    final f = raw[i];
    if (f == null) continue;
    final near = [
      for (var j = max(0, i - 3); j <= min(n - 1, i + 3); j++)
        if (j != i) ?raw[j],
    ];
    if (near.length < 2) {
      out[i] = null; // a lone voiced frame is usually noise
      continue;
    }
    near.sort();
    final m = near[near.length ~/ 2];
    final r = f / m;
    if (r > 1.7 && r < 2.3) {
      out[i] = f / 2;
    } else if (r > 0.43 && r < 0.59) {
      out[i] = f * 2;
    } else if (r > 1.7 || r < 0.59) {
      out[i] = null;
    }
  }
  // Octave slips longer than the window above: keep each frame within an
  // octave of the voiced frame before it (up to 50 ms back).
  double? prev;
  var prevAt = -100;
  for (var i = 0; i < n; i++) {
    var f = out[i];
    if (f == null) continue;
    if (prev != null && i - prevAt <= 5) {
      final r = f / prev;
      if (r > 1.7 && r < 2.3) {
        f = f / 2;
      } else if (r > 0.43 && r < 0.59) {
        f = f * 2;
      }
      out[i] = f;
    }
    prev = f;
    prevAt = i;
  }
  final smooth = List<double?>.filled(n, null);
  for (var i = 0; i < n; i++) {
    if (out[i] == null) continue;
    final w = [
      for (var j = max(0, i - 2); j <= min(n - 1, i + 2); j++) ?out[j],
    ]..sort();
    smooth[i] = w[w.length ~/ 2];
  }
  return smooth;
}
