import '../models/entry.dart';
import 'heard.dart';
import 'tone_shape.dart';

/// The verdict at the top of a "Say it" result.
enum Verdict { matched, close, different, nothing }

Verdict verdictOf(WordCheck c) {
  if (c.heardNothing) return Verdict.nothing;
  if (c.allRight) return Verdict.matched;
  final right = c.syllables.where((s) => s.heard == Heard.right).length;
  return right * 2 >= c.syllables.length ? Verdict.close : Verdict.different;
}

String headline(Entry e, WordCheck c) => switch (verdictOf(c)) {
      Verdict.matched => 'It heard ${e.simplified.replaceAll(RegExp(r'[，。？！、,.?!\s]'), '')}',
      Verdict.close => 'Nearly: it heard ${c.text}',
      Verdict.different => 'It heard ${c.text}',
      Verdict.nothing => 'It didn\'t catch a word',
    };

/// One line per syllable that went wrong, in plain words.
List<String> problems(WordCheck c) => [
      for (final s in c.syllables)
        switch (s.heard) {
          Heard.right => null,
          Heard.tone =>
            '${s.syllable.hanzi} ${s.syllable.pinyin} came out as ${s.char} ${s.reading}, a ${_ordinal(_toneOf(s.reading))} tone. '
                'Aim for ${_toneWords(s.syllable.spokenTone)}.',
          Heard.sound => s.reading == null
              ? '${s.syllable.hanzi} ${s.syllable.pinyin} sounded like ${s.char}.'
              : '${s.syllable.hanzi} ${s.syllable.pinyin} sounded like ${s.char} ${s.reading}.',
          Heard.missed => 'It didn\'t hear ${s.syllable.hanzi} ${s.syllable.pinyin}.',
        },
      if (c.extra.isNotEmpty) 'It also heard ${c.extra.join()}, which isn\'t in the ${c.syllables.length == 1 ? 'word' : 'phrase'}.',
    ].nonNulls.toList();

/// A short note on what the result can and can't tell you.
String caveat(Entry e, WordCheck c) {
  final v = verdictOf(c);
  if (v == Verdict.nothing) {
    return e.syllables.length == 1
        ? 'One syllable on its own is hard for the recogniser, even from native speakers. Try again, or check the pitch line below.'
        : 'Try again a little louder and closer to the microphone.';
  }
  if (v == Verdict.matched && e.syllables.length > 3) {
    return 'A longer phrase can match even with small slips, because the recogniser guesses from context.';
  }
  if (v == Verdict.matched) return 'A match means the recogniser understood you. It isn\'t a full pronunciation score.';
  return 'The recogniser is a guide, not a teacher: it gets about 1 in 20 two-syllable words wrong even from a native voice.';
}

int _toneOf(String? reading) {
  if (reading == null) return 5;
  for (final (marks, tone) in const [('āēīōūǖ', 1), ('áéíóúǘ', 2), ('ǎěǐǒǔǚ', 3), ('àèìòùǜ', 4)]) {
    if (reading.split('').any(marks.contains)) return tone;
  }
  return 5;
}

String _ordinal(int t) => switch (t) { 1 => '1st', 2 => '2nd', 3 => '3rd', 4 => '4th', _ => 'neutral' };

String _toneWords(int t) =>
    t >= 1 && t <= 4 ? 'the ${_ordinal(t)} tone: ${toneTarget(t)}' : 'a light, short neutral tone';
