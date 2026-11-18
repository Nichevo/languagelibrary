import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/entry.dart';
import 'library.dart';

/// Key sounds: pairs of library words that differ in one sound, for
/// hear-and-pick practice. Made by tools/sound_pairs.py
/// (assets/data/sound_pairs.json). The pinyin and clips are the library's own;
/// the only new text is each group's tip, summarised from a cited source.

/// One thing that tells two sounds apart, like sh / s or 2nd / 3rd tone.
class SoundContrast {
  const SoundContrast(this.id, this.label, this.group);

  /// 'hiss:sh/s', 'tones:2/3'.
  final String id;

  /// 'sh / s', '2nd / 3rd tone'.
  final String label;
  final String group;
}

/// A family of contrasts, shown together: Tones, Puffs of air ...
class SoundGroup {
  const SoundGroup(this.id, this.title, this.kind, this.tip, this.tipSource, this.heardCheck, this.contrasts);
  final String id, title;

  /// 'tone', 'initial' or 'final': which part of the syllable changes.
  final String kind;
  final String tip, tipSource;

  /// Whether the speech recogniser was good enough on this group's clips to
  /// say which of the two words it heard (see tools/sound_pairs_report.md).
  final bool heardCheck;
  final List<SoundContrast> contrasts;
}

/// Two sounds one contrast apart. Each side lists every library word said
/// that way, easiest first (是 事 试 are all shì).
class SoundPair {
  const SoundPair(this.contrast, this.aPinyin, this.aIds, this.bPinyin, this.bIds, this.level);
  final String contrast;
  final String aPinyin, bPinyin;
  final List<String> aIds, bIds;
  final int level;
}

/// A pair with one word picked for each side, as shown.
class ShownPair {
  const ShownPair(this.pair, this.a, this.b);
  final SoundPair pair;
  final Entry a, b;
}

class KeySounds {
  const KeySounds(this.groups, this.pairs);
  final List<SoundGroup> groups;
  final List<SoundPair> pairs;

  static const empty = KeySounds([], []);

  factory KeySounds.fromJson(Map<String, dynamic> j) => KeySounds(
        [
          for (final g in j['groups'] as List)
            SoundGroup(
              g['id'] as String,
              g['title'] as String,
              g['kind'] as String,
              g['tip'] as String,
              g['tipSource'] as String,
              g['heardCheck'] as bool? ?? false,
              [for (final c in g['contrasts'] as List) SoundContrast(c['id'] as String, c['label'] as String, g['id'] as String)],
            ),
        ],
        [
          for (final p in j['pairs'] as List)
            SoundPair(
              p['contrast'] as String,
              p['a']['pinyin'] as String,
              List<String>.from(p['a']['ids'] as List),
              p['b']['pinyin'] as String,
              List<String>.from(p['b']['ids'] as List),
              p['level'] as int,
            ),
        ],
      );

  static Future<KeySounds> load([AssetBundle? bundle]) async {
    try {
      final text = await (bundle ?? rootBundle).loadString('assets/data/sound_pairs.json');
      return KeySounds.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return empty;
    }
  }

  SoundGroup? group(String id) => groups.where((g) => g.id == id).firstOrNull;

  SoundContrast? contrast(String id) {
    for (final g in groups) {
      for (final c in g.contrasts) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// The pairs that can be shown: each side needs a word that [shows] lets
  /// through (the level switches), and the first such word is used.
  List<ShownPair> shown(Library lib, bool Function(Entry) shows, {String? group, String? contrast}) {
    Entry? pick(List<String> ids) {
      for (final id in ids) {
        final e = lib.byId[id];
        if (e != null && shows(e)) return e;
      }
      return null;
    }

    return [
      for (final p in pairs)
        if ((contrast == null || p.contrast == contrast) && (group == null || p.contrast.startsWith('$group:')))
          if ((pick(p.aIds), pick(p.bIds)) case (final a?, final b?)) ShownPair(p, a, b),
    ];
  }
}

String groupOf(String contrastId) => contrastId.split(':').first;

/// One hear-and-pick answer.
class SoundTry {
  const SoundTry(this.at, this.contrast, this.played, this.picked);
  final DateTime at;
  final String contrast;

  /// The word played and the word picked (the same when right).
  final String played, picked;

  bool get right => played == picked;

  List<Object> toJson() => [at.millisecondsSinceEpoch, contrast, played, picked];

  factory SoundTry.fromJson(List j) =>
      SoundTry(DateTime.fromMillisecondsSinceEpoch((j[0] as num).toInt()), j[1] as String, j[2] as String, j[3] as String);
}

/// How a contrast is going: its last [window] answers.
class ContrastScore {
  const ContrastScore(this.right, this.total, this.runOfRight);
  final int right, total;

  /// Right answers in a row, counting back from the latest.
  final int runOfRight;

  double get share => total == 0 ? 0 : right / total;
}

/// A contrast counts as trouble once it has [troubleMin] answers and under
/// [troubleBelow] of the last [window] are right. It stops being trouble after
/// [troubleClear] right in a row.
const window = 20, troubleMin = 6, troubleBelow = 0.75, troubleClear = 8;

Map<String, ContrastScore> contrastScores(List<SoundTry> tries) {
  final by = <String, List<SoundTry>>{};
  for (final t in tries) {
    by.putIfAbsent(t.contrast, () => []).add(t);
  }
  return {
    for (final MapEntry(:key, :value) in by.entries)
      key: () {
        final last = value.length > window ? value.sublist(value.length - window) : value;
        var run = 0;
        for (final t in value.reversed) {
          if (!t.right) break;
          run++;
        }
        return ContrastScore(last.where((t) => t.right).length, last.length, run);
      }(),
  };
}

bool isTrouble(ContrastScore s) => s.total >= troubleMin && s.share < troubleBelow && s.runOfRight < troubleClear;

/// Trouble contrasts, worst first.
List<String> troubleSounds(List<SoundTry> tries) {
  final scores = contrastScores(tries);
  return [for (final e in scores.entries) if (isTrouble(e.value)) e.key]
    ..sort((a, b) => scores[a]!.share.compareTo(scores[b]!.share));
}

/// One round: the pair, and which side is played.
class SoundQuestion {
  const SoundQuestion(this.pair, this.playA);
  final ShownPair pair;
  final bool playA;

  Entry get played => playA ? pair.a : pair.b;
}

/// [count] rounds from [pool]. When [trouble] is given, about 7 rounds in 10
/// come from those contrasts. Pairs and sides are random; no pair twice in a
/// row.
List<SoundQuestion> soundQuestions(List<ShownPair> pool, Random rnd, {int count = 10, List<String> trouble = const []}) {
  if (pool.isEmpty) return [];
  final hard = [for (final p in pool) if (trouble.contains(p.pair.contrast)) p];
  final rest = [for (final p in pool) if (!trouble.contains(p.pair.contrast)) p];
  final out = <SoundQuestion>[];
  ShownPair? last;
  for (var i = 0; i < count; i++) {
    final from = hard.isNotEmpty && (rest.isEmpty || rnd.nextDouble() < 0.7) ? hard : (rest.isEmpty ? pool : rest);
    var p = from[rnd.nextInt(from.length)];
    if (from.length > 1) {
      while (identical(p, last)) {
        p = from[rnd.nextInt(from.length)];
      }
    }
    last = p;
    out.add(SoundQuestion(p, rnd.nextBool()));
  }
  return out;
}

/// The letters that differ between two pinyin syllables, as (start, end) in
/// [a], for colouring. Tone marks count as differing letters.
(int, int) differingPart(String a, String b) {
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length, endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  return (start, endA);
}
