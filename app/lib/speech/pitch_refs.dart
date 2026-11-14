import 'dart:convert';

import 'package:flutter/services.dart';

/// The pitch lines of the app's own voice clips, made by tools/pitch_refs.py
/// with the same tracker as the learner's line. Drawn dotted on the Say it
/// pitch graph as a guide to aim for.
class PitchRefs {
  PitchRefs(this._lines);

  final Map<String, String> _lines;

  /// Seconds per character of a line.
  static const step = 0.02;

  static Future<PitchRefs>? _loading;

  /// assets/audio/pitch_refs.json, loaded once. Empty when it's missing.
  static Future<PitchRefs> load([AssetBundle? bundle]) => _loading ??= () async {
        try {
          // Decoded here rather than with loadString, which hands big files to
          // another isolate.
          final data = await (bundle ?? rootBundle).load('assets/audio/pitch_refs.json');
          final j = jsonDecode(utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)))
              as Map<String, dynamic>;
          return PitchRefs.parse(j);
        } catch (_) {
          return PitchRefs(const {});
        }
      }();

  factory PitchRefs.parse(Map<String, dynamic> j) => PitchRefs({
        for (final MapEntry(:key, :value) in ((j['clips'] as Map?) ?? const {}).entries)
          if ((value as Map)['line'] case final String line when line.isNotEmpty) key as String: line,
      });

  /// The line for clip [key] (for example "abc123_f"), as semitones from the
  /// clip's middle pitch every [step] seconds, null where there is no voice.
  List<double?>? lineFor(String key) => switch (_lines[key]) {
        final s? => decode(s),
        null => null,
      };

  static List<double?> decode(String s) => [
        for (final c in s.codeUnits) c == 0x2e ? null : (c - 0x30 - 18) / 2,
      ];
}
