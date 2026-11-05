/// One word or phrase from assets/data/library.json (built by tools/build_data.py).
class Entry {
  Entry({
    required this.id,
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    required this.pinyinNumbered,
    required this.meanings,
    required this.classifiers,
    required this.hsk,
    required this.topics,
    required this.syllables,
    required this.spoken,
    required this.soundNotes,
    required this.notes,
    required this.polyphonic,
    required this.sources,
  });

  final String id;
  final String simplified;
  final String traditional;
  final String pinyin;
  final String pinyinNumbered;
  final List<String> meanings;
  final List<Classifier> classifiers;
  final int? hsk;
  final List<String> topics;
  final List<SyllableInfo> syllables;

  /// How it is actually said when tone changes apply (e.g. "ní hǎo"), else null.
  final String? spoken;
  final List<String> soundNotes;
  final List<String> notes;
  final bool polyphonic;
  final List<String> sources;

  /// Short English summary for lists and flashcards.
  String get gloss => meanings.take(3).join('; ');

  /// Lower-case pinyin without tone marks or spaces, for searching.
  late final String searchPinyin = stripTones(pinyin).replaceAll(' ', '');
  late final String searchNumbered =
      pinyinNumbered.toLowerCase().replaceAll(' ', '').replaceAll('u:', 'ü');
  late final String searchEnglish = meanings.join(' / ').toLowerCase();

  factory Entry.fromJson(Map<String, dynamic> j) {
    final pron = j['pronunciation'] as Map<String, dynamic>;
    return Entry(
      id: j['id'] as String,
      simplified: j['simplified'] as String,
      traditional: j['traditional'] as String,
      pinyin: j['pinyin'] as String,
      pinyinNumbered: j['pinyinNumbered'] as String,
      meanings: List<String>.from(j['meanings'] as List),
      classifiers: [
        for (final c in j['classifiers'] as List)
          Classifier(c['hanzi'] as String, c['pinyin'] as String),
      ],
      hsk: j['hsk'] as int?,
      topics: List<String>.from(j['topics'] as List),
      syllables: [
        for (final s in pron['syllables'] as List)
          SyllableInfo.fromJson(s as Map<String, dynamic>),
      ],
      spoken: pron['spoken'] as String?,
      soundNotes: List<String>.from(pron['notes'] as List),
      notes: List<String>.from((j['notes'] as List?) ?? const []),
      polyphonic: j['polyphonic'] as bool? ?? false,
      sources: List<String>.from(j['sources'] as List),
    );
  }
}

class Classifier {
  const Classifier(this.hanzi, this.pinyin);
  final String hanzi;
  final String pinyin;
}

class SyllableInfo {
  const SyllableInfo({
    required this.hanzi,
    required this.pinyin,
    required this.initial,
    required this.finalPart,
    required this.tone,
    required this.toneName,
    required this.spokenTone,
  });

  final String? hanzi;
  final String pinyin;
  final String initial;
  final String finalPart;
  final int tone;
  final String toneName;
  final int spokenTone;

  factory SyllableInfo.fromJson(Map<String, dynamic> j) => SyllableInfo(
        hanzi: j['hanzi'] as String?,
        pinyin: j['pinyin'] as String,
        initial: j['initial'] as String,
        finalPart: j['final'] as String,
        tone: j['tone'] as int,
        toneName: j['toneName'] as String,
        spokenTone: j['spokenTone'] as int,
      );
}

const _toneless = {
  'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
  'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
  'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
  'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
  'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
  'ǖ': 'ü', 'ǘ': 'ü', 'ǚ': 'ü', 'ǜ': 'ü',
};

/// "Nǐ hǎo" -> "ni hao"
String stripTones(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_toneless[ch] ?? ch);
  }
  return b.toString();
}
