import '../models/entry.dart';

/// Readings with tones for each character ("jian4"), from
/// assets/data/char_tones.tsv (made by tools/char_tones.py from CC-CEDICT).
class CharTones {
  CharTones(this.byChar);

  final Map<String, List<String>> byChar;

  factory CharTones.parse(String tsv) => CharTones({
        for (final line in tsv.split('\n'))
          if (line.isNotEmpty && !line.startsWith('#'))
            line.substring(0, line.indexOf('\t')): line.substring(line.indexOf('\t') + 1).trim().split(' '),
      });
}

/// How one expected syllable came out.
enum Heard {
  /// The recogniser wrote a character with this sound and tone.
  right,

  /// Same sound, different tone (卖 mài for 买 mǎi).
  tone,

  /// A different sound (是 shì for 吃 chī).
  sound,

  /// Nothing was written for it.
  missed,
}

class SyllableCheck {
  const SyllableCheck(this.syllable, this.heard, {this.char, this.reading});
  final SyllableInfo syllable;
  final Heard heard;

  /// What the recogniser wrote instead, and how that is read (tone marks).
  final String? char;
  final String? reading;
}

/// What the recogniser heard, syllable by syllable.
class WordCheck {
  const WordCheck(this.text, this.syllables, this.extra);

  /// What it wrote, Chinese characters only.
  final String text;
  final List<SyllableCheck> syllables;

  /// Characters it wrote that match nothing expected.
  final List<String> extra;

  bool get heardNothing => text.isEmpty;
  bool get allRight => syllables.every((s) => s.heard == Heard.right) && extra.isEmpty;
  int get wrong => syllables.where((s) => s.heard != Heard.right).length + extra.length;
}

final _han = RegExp(r'[㐀-鿿]');

/// Lines up the syllables of [entry] with the characters in [transcript].
///
/// A character counts as right when it can be read with the expected sound
/// and tone, so 见 for 件 (both jiàn) is fine. The tone may be the written one
/// or the one actually said after a tone change (不 bú in 不是). Neutral tones
/// are not checked, since the recogniser writes characters, not how lightly
/// they were said. A dropped 儿 is fine: recognisers usually leave it out.
WordCheck checkHeard(Entry entry, String transcript, CharTones tones) {
  final heard = [for (final m in _han.allMatches(transcript)) m.group(0)!];
  final want = [for (final s in entry.syllables) if (s.hanzi == null || _han.hasMatch(s.hanzi!)) s];
  final n = want.length, m = heard.length;

  // Edit distance, with a cheap step for a tone-only miss.
  (double, Heard, String?) match(SyllableInfo s, String ch) {
    final base = _numbered(s).$1;
    final readings = tones.byChar[ch] ?? const [];
    final same = [for (final r in readings) if (r.substring(0, r.length - 1) == base) r];
    if (ch == s.hanzi && same.isEmpty) return (0, Heard.right, null);
    if (same.isEmpty) return (1, Heard.sound, readings.isEmpty ? null : readings.first);
    final okTones = {s.tone, s.spokenTone};
    final fits = same.any((r) {
      final t = int.parse(r[r.length - 1]);
      return s.tone == 5 || s.spokenTone == 5 || t == 5 || okTones.contains(t);
    });
    if (fits) return (0, Heard.right, null);
    return (0.4, Heard.tone, same.first);
  }

  double skip(SyllableInfo s) => _numbered(s).$1 == 'r' ? 0.1 : 1;

  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = cost[i - 1][0] + skip(want[i - 1]);
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j.toDouble();
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = cost[i - 1][j - 1] + match(want[i - 1], heard[j - 1]).$1;
      final del = cost[i - 1][j] + skip(want[i - 1]);
      final ins = cost[i][j - 1] + 1;
      cost[i][j] = [sub, del, ins].reduce((a, b) => a < b ? a : b);
    }
  }

  final checks = <SyllableCheck>[];
  final extra = <String>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final (c, how, reading) = match(want[i - 1], heard[j - 1]);
      if ((cost[i][j] - (cost[i - 1][j - 1] + c)).abs() < 1e-9) {
        checks.add(SyllableCheck(want[i - 1], how,
            char: heard[j - 1], reading: reading == null ? null : markTone(reading)));
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && (j == 0 || (cost[i][j] - (cost[i - 1][j] + skip(want[i - 1]))).abs() < 1e-9)) {
      final s = want[i - 1];
      checks.add(SyllableCheck(s, _numbered(s).$1 == 'r' ? Heard.right : Heard.missed));
      i--;
      continue;
    }
    extra.add(heard[j - 1]);
    j--;
  }
  return WordCheck(heard.join(), checks.reversed.toList(), extra.reversed.toList());
}

/// "jiàn" -> ("jian", 4); the neutral tone is 5.
(String, int) _numbered(SyllableInfo s) => (_toneless(s.pinyin.toLowerCase()), s.tone);

String _toneless(String p) {
  final b = StringBuffer();
  for (final ch in p.split('')) {
    b.write(_marks[ch]?.$1 ?? ch);
  }
  return b.toString().replaceAll(RegExp(r"[^a-zü]"), '');
}

const _marks = {
  'ā': ('a', 1), 'á': ('a', 2), 'ǎ': ('a', 3), 'à': ('a', 4),
  'ē': ('e', 1), 'é': ('e', 2), 'ě': ('e', 3), 'è': ('e', 4),
  'ī': ('i', 1), 'í': ('i', 2), 'ǐ': ('i', 3), 'ì': ('i', 4),
  'ō': ('o', 1), 'ó': ('o', 2), 'ǒ': ('o', 3), 'ò': ('o', 4),
  'ū': ('u', 1), 'ú': ('u', 2), 'ǔ': ('u', 3), 'ù': ('u', 4),
  'ǖ': ('ü', 1), 'ǘ': ('ü', 2), 'ǚ': ('ü', 3), 'ǜ': ('ü', 4),
};

/// "jian4" -> "jiàn", "nü3" -> "nǚ", "ma5" -> "ma".
String markTone(String numbered) {
  final tone = int.tryParse(numbered.substring(numbered.length - 1));
  final s = tone == null ? numbered : numbered.substring(0, numbered.length - 1);
  if (tone == null || tone < 1 || tone > 4) return s;
  // The mark goes on a or e; on the o of ou; otherwise on the last vowel.
  int at;
  if (s.contains('a')) {
    at = s.indexOf('a');
  } else if (s.contains('e')) {
    at = s.indexOf('e');
  } else if (s.contains('ou')) {
    at = s.indexOf('o');
  } else {
    at = s.lastIndexOf(RegExp('[iouü]'));
  }
  if (at < 0) return s;
  final v = s[at];
  final marked = _marks.entries.firstWhere((e) => e.value == (v, tone)).key;
  return s.substring(0, at) + marked + s.substring(at + 1);
}
