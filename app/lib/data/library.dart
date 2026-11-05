import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/entry.dart';

/// The read-only word library plus the list of audio clips that exist.
class Library {
  Library(this.entries, {Map<String, String>? audioFiles})
      : audioFiles = audioFiles ?? const {},
        byId = {for (final e in entries) e.id: e};

  final List<Entry> entries;
  final Map<String, Entry> byId;

  /// `id_f` / `id_m` -> file name under assets/audio/.
  final Map<String, String> audioFiles;

  static const topics = ['everyday', 'food', 'travel', 'family', 'love', 'numbers'];

  static Future<Library> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final data = jsonDecode(await b.loadString('assets/data/library.json'))
        as Map<String, dynamic>;
    final entries = [
      for (final e in data['entries'] as List) Entry.fromJson(e as Map<String, dynamic>),
    ];
    final audio = <String, String>{};
    try {
      final manifest = jsonDecode(await b.loadString('assets/audio/manifest.json'))
          as Map<String, dynamic>;
      final clips = (manifest['clips'] as Map?) ?? const {};
      clips.forEach((key, value) => audio[key as String] = (value as Map)['file'] as String);
    } catch (_) {
      // No studio audio made yet: the app falls back to the phone's own voice.
    }
    return Library(entries, audioFiles: audio);
  }

  String? audioFor(Entry e, {required bool female}) => audioFiles['${e.id}_${female ? 'f' : 'm'}'];

  /// Search by hanzi, pinyin (with or without tones, spaces or numbers) or English.
  List<Entry> search(String query, {String? topic}) {
    final q = query.trim().toLowerCase();
    Iterable<Entry> pool = entries;
    if (topic != null) pool = pool.where((e) => e.topics.contains(topic));
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
