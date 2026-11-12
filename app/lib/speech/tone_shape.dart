import 'pitch.dart';

/// What a tone should sound like, in the words the app uses for it.
String toneTarget(int tone) => switch (tone) {
      1 => 'high and level',
      2 => 'rising',
      3 => 'low, dipping',
      4 => 'falling',
      _ => 'light and short',
    };

/// Stretches of voice, allowing short breaks (up to 40 ms), as (first frame,
/// frame after the last). Stretches shorter than 50 ms are dropped.
List<(int, int)> voicedRuns(List<double?> hz) {
  final out = <(int, int)>[];
  int? start;
  var lastVoiced = -100;
  for (var i = 0; i < hz.length; i++) {
    if (hz[i] == null) continue;
    if (start != null && i - lastVoiced > 4) {
      out.add((start, lastVoiced + 1));
      start = null;
    }
    start ??= i;
    lastVoiced = i;
  }
  if (start != null) out.add((start, lastVoiced + 1));
  return [for (final r in out) if (r.$2 - r.$1 >= 5) r];
}

/// The pitch line to draw: the voiced stretches, in semitones from the
/// speaker's middle pitch, with times in seconds.
class PitchPicture {
  const PitchPicture(this.lines, this.start, this.end);

  /// Each voiced stretch as (seconds, semitones) points.
  final List<List<(double, double)>> lines;

  /// The span worth showing, a little either side of the voice.
  final double start, end;

  bool get isEmpty => lines.isEmpty;

  factory PitchPicture.of(PitchTrack track) {
    final st = track.semitones;
    final runs = voicedRuns(track.hz);
    if (runs.isEmpty) return const PitchPicture([], 0, 1);
    const hop = PitchTrack.hop;
    return PitchPicture(
      [
        for (final (a, b) in runs)
          [
            for (var i = a; i < b; i++)
              if (st[i] != null) (i * hop + 0.0125, st[i]!.clamp(-9.0, 9.0)),
          ],
      ],
      runs.first.$1 * hop - 0.1,
      runs.last.$2 * hop + 0.1,
    );
  }
}
