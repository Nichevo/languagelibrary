import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/entry.dart';
import 'conversations.dart';
import 'key_sounds.dart';

/// One word on a scale, with the meaning that puts it there.
class ScaleItem {
  const ScaleItem(this.entry, this.meaning);
  final Entry entry;
  final String meaning;

  /// The meaning without notes in brackets: "pleasantly cool (weather etc)" -> "pleasantly cool".
  String get short => meaning.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split(';').first.trim();
}

/// Words on the same line, from one end to the other (cold -> hot). The words
/// and meanings are the library's; which words and their order were picked by hand.
class Scale {
  const Scale(this.name, this.from, this.to, this.items);
  final String name, from, to;
  final List<ScaleItem> items;

}

/// Two words that are opposites, with the English meanings that make them so
/// (from the "Opposite: big / small" related-word links).
typedef OppositePair = ({Entry a, String aEnglish, Entry b, String bEnglish});

/// The read-only word library plus the list of audio clips that exist.
/// One piece of a pattern example, with what it does in the sentence
/// ("who", "when", "where", "action" …). How sentences are split is ours.
class Chunk {
  const Chunk(this.text, this.role);
  final String text;
  final String role;
}

/// A pattern example: a phrasebook sentence split into chunks, in Chinese
/// order and in English order.
class PatternExample {
  PatternExample(this.sentence, this.zh, this.en);
  final Entry sentence;
  final List<Chunk> zh;
  final List<Chunk> en;

  /// The pinyin of each Chinese chunk, from the sentence's own syllables.
  late final List<String> zhPinyin = () {
    final syl = sentence.syllables;
    var i = 0;
    return [
      for (final c in zh)
        [
          for (final ch in c.text.runes.map(String.fromCharCode))
            if (i < syl.length && syl[i].hanzi == ch) syl[i++].pinyin,
        ].join(' '),
    ];
  }();
}

/// How Chinese orders a kind of sentence, next to English.
class SentencePattern {
  const SentencePattern(this.id, this.name, this.rule, this.sourceTitle, this.sourceUrl, this.examples);
  final String id, name, rule, sourceTitle, sourceUrl;
  final List<PatternExample> examples;
}

class Library {
  Library(this.entries,
      {Map<String, String>? audioFiles,
      this.scales = const [],
      this.patterns = const [],
      Conversations? conversations,
      this.keySounds = KeySounds.empty})
      : audioFiles = audioFiles ?? const {},
        conversations = conversations ?? Conversations.empty,
        byId = {for (final e in entries) e.id: e};

  final List<Entry> entries;
  final Map<String, Entry> byId;
  final List<Scale> scales;
  final List<SentencePattern> patterns;

  /// The checked conversation scenes (Practice > Conversations).
  final Conversations conversations;

  /// Sound pairs for Practice > Key sounds.
  final KeySounds keySounds;

  /// The patterns that use sentence [e] as an example.
  List<SentencePattern> patternsFor(Entry e) =>
      [for (final p in patterns) if (p.examples.any((x) => x.sentence.id == e.id)) p];

  /// The scales [e] is on.
  List<Scale> scalesFor(Entry e) => [for (final s in scales) if (s.items.any((i) => i.entry.id == e.id)) s];

  /// Every opposite pair once, in library order.
  late final List<OppositePair> opposites = () {
    final seen = <String>{};
    final out = <OppositePair>[];
    for (final e in entries) {
      for (final r in e.related) {
        final o = byId[r.id];
        if (o == null || !r.why.startsWith('Opposite:')) continue;
        final key = ([e.id, o.id]..sort()).join();
        final english = r.why.substring('Opposite:'.length).split('/');
        if (seen.add(key) && english.length == 2) {
          out.add((a: e, aEnglish: english[0].trim(), b: o, bEnglish: english[1].trim()));
        }
      }
    }
    return out;
  }();

  /// `id_f` / `id_m` -> file name under assets/audio/.
  final Map<String, String> audioFiles;

  /// The HSK levels in the data, lowest first.
  late final List<int> levels = ({for (final e in entries) ?e.hsk}.toList()..sort());

  static const topics = ['everyday', 'food', 'travel', 'family', 'love', 'numbers'];

  /// Pass as the topic to search only the phrasebook sentences.
  static const sentencesFilter = 'sentences';

  /// The Library chip that shows scales and opposite pairs.
  static const scalesFilter = 'scales';

  /// The Library chip that shows tone sets and other tricky sounds.
  static const soundsFilter = 'sounds';

  /// The Library chips for character families and sentence patterns.
  static const familiesFilter = 'families';
  static const patternsFilter = 'patterns';

  /// The library from the parsed library.json.
  factory Library.fromJson(Map<String, dynamic> data,
      {Map<String, String>? audioFiles, Conversations? conversations, KeySounds keySounds = KeySounds.empty}) {
    final entries = [
      for (final e in data['entries'] as List) Entry.fromJson(e as Map<String, dynamic>),
    ];
    final byId = {for (final e in entries) e.id: e};
    final scales = [
      for (final s in (data['scales'] as List?) ?? const [])
        Scale(s['name'] as String, s['from'] as String, s['to'] as String, [
          for (final i in s['items'] as List)
            if (byId[i['id']] case final e?) ScaleItem(e, i['meaning'] as String),
        ]),
    ];
    List<Chunk> chunks(List l) => [for (final c in l) Chunk(c[0] as String, c[1] as String)];
    final patterns = [
      for (final p in (data['patterns'] as List?) ?? const [])
        SentencePattern(p['id'] as String, p['name'] as String, p['rule'] as String, p['source']['title'] as String,
            p['source']['url'] as String, [
          for (final x in p['examples'] as List)
            if (byId[x['id']] case final e?) PatternExample(e, chunks(x['zh'] as List), chunks(x['en'] as List)),
        ]),
    ];
    return Library(entries,
        audioFiles: audioFiles, scales: scales, patterns: patterns, conversations: conversations, keySounds: keySounds);
  }

  static Future<Library> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final data = jsonDecode(await b.loadString('assets/data/library.json'))
        as Map<String, dynamic>;
    final audio = <String, String>{};
    try {
      final manifest = jsonDecode(await b.loadString('assets/audio/manifest.json'))
          as Map<String, dynamic>;
      final clips = (manifest['clips'] as Map?) ?? const {};
      clips.forEach((key, value) {
        // A clip that speech recognition couldn't confirm is never played; the
        // phone's own voice says that word instead (see tools/audio_report.md).
        if ((value as Map)['check'] == 'mismatch') return;
        audio[key as String] = value['file'] as String;
      });
    } catch (_) {
      // No studio audio made yet: the app falls back to the phone's own voice.
    }
    return Library.fromJson(data,
        audioFiles: audio, conversations: await Conversations.load(b), keySounds: await KeySounds.load(b));
  }

  String? audioFor(Entry e, {required bool female}) => audioFiles['${e.id}_${female ? 'f' : 'm'}'];

  /// Search by hanzi, pinyin (with or without tones, spaces or numbers) or English.
  /// [shown] limits the results to the content switched on in Settings.
  List<Entry> search(String query, {String? topic, bool Function(Entry)? shown}) {
    final q = query.trim().toLowerCase();
    Iterable<Entry> pool = shown == null ? entries : entries.where(shown);
    if (topic == sentencesFilter) {
      pool = pool.where((e) => e.isSentence);
    } else if (topic != null) {
      pool = pool.where((e) => e.topics.contains(topic));
    }
    if (q.isEmpty) return pool.toList();

    final qPinyin = stripTones(q).replaceAll(' ', '').replaceAll('v', 'ü');
    final qNumbered = q.replaceAll(' ', '').replaceAll('v', 'ü');
    final scored = <(int, Entry)>[];
    for (final e in pool) {
      int? score;
      if (e.simplified == q || e.traditional == q) {
        score = 0;
      } else if (e.simplified.contains(q)) {
        score = 1;
      } else if (e.searchPinyin == qPinyin || e.searchNumbered == qNumbered) {
        score = 2;
      } else if (e.searchPinyin.startsWith(qPinyin) || e.searchNumbered.startsWith(qNumbered)) {
        score = 3;
      } else if (RegExp(r'\b' + RegExp.escape(q) + r'\b').hasMatch(e.searchEnglish)) {
        score = 4;
      } else if (e.searchEnglish.contains(q)) {
        score = 5;
      }
      if (score != null) scored.add((score, e));
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final s in scored) s.$2];
  }
}
