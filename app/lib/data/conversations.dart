import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/entry.dart';

/// One reply you could pick: the line, and which line the app says after it
/// (null when the scene ends there).
class ReplyChoice {
  const ReplyChoice(this.entry, this.right, this.then);
  final Entry entry;
  final bool right;
  final String? then;
}

/// A short conversation from the Chinese Dialogues Podcast, checked in English
/// before it went in (tools/sources/coerll/approved.tsv).
class Scene {
  const Scene(this.id, this.title, this.hsk, this.lines);
  final String id, title;
  final int hsk;

  /// Line ids in order, for example d2.1, d2.2.
  final List<String> lines;
}

/// The checked scenes, built by `python -m tools.dialogues` into
/// assets/data/conversations.json.
class Conversations {
  Conversations({this.entries = const {}, this.scenes = const [], this.next = const {}, this.turns = const {}});

  /// Every line as an entry, by entry id (conv-d2.1).
  final Map<String, Entry> entries;
  final List<Scene> scenes;

  /// Line id -> the line after it in a checked scene, or null at the end.
  final Map<String, String?> next;

  /// Line id -> the right and wrong replies offered in its place.
  final Map<String, ({List<(String, String?)> right, List<String> wrong})> turns;

  static final empty = Conversations();

  bool get isEmpty => scenes.isEmpty;

  /// The entry for a line id.
  Entry? line(String lineId) => entries['conv-$lineId'];

  /// The three choices offered where [lineId] comes, in a mixed order.
  /// Null when there is no turn there (the very first line).
  List<ReplyChoice>? choices(String lineId, {int seed = 0}) {
    final t = turns[lineId];
    if (t == null) return null;
    final out = <ReplyChoice>[
      for (final (id, then) in t.right)
        if (entries[id] case final e?) ReplyChoice(e, true, then),
      for (final id in t.wrong)
        if (entries[id] case final e?) ReplyChoice(e, false, null),
    ];
    // A fixed shuffle per line, so the right reply isn't always first but the
    // order doesn't jump about when you go back to a scene.
    final key = lineId.codeUnits.fold<int>(seed, (a, b) => (a * 31 + b) & 0x7fffffff);
    for (var i = out.length - 1; i > 0; i--) {
      final j = (key + i * 7) % (i + 1);
      final x = out[i];
      out[i] = out[j];
      out[j] = x;
    }
    return out;
  }

  factory Conversations.fromJson(Map<String, dynamic> j) {
    final entries = {
      for (final e in j['entries'] as List) (e['id'] as String): Entry.fromJson(e as Map<String, dynamic>),
    };
    return Conversations(
      entries: entries,
      scenes: [
        for (final s in j['scenes'] as List)
          Scene(s['id'] as String, s['title'] as String, s['hsk'] as int, List<String>.from(s['lines'] as List)),
      ],
      next: {for (final MapEntry(:key, :value) in (j['next'] as Map).entries) key as String: value as String?},
      turns: {
        for (final MapEntry(:key, :value) in (j['turns'] as Map).entries)
          key as String: (
            right: [for (final r in value['right'] as List) (r['entry'] as String, r['then'] as String?)],
            wrong: List<String>.from(value['wrong'] as List),
          ),
      },
    );
  }

  /// The checked scenes, or none if the file isn't there yet.
  static Future<Conversations> load([AssetBundle? bundle]) async {
    try {
      final text = await (bundle ?? rootBundle).loadString('assets/data/conversations.json');
      return Conversations.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return empty;
    }
  }
}
