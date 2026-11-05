import 'dart:convert';

import 'package:flutter/services.dart';

import 'user_store.dart';

/// One part of what the app keeps on the phone.
class StoragePart {
  const StoragePart(this.label, this.detail, this.bytes);
  final String label;
  final String detail;
  final int bytes;
}

/// How much space each bundled part of the library takes, from the files in the app.
Future<List<StoragePart>> libraryStorage([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final parts = <StoragePart>[];

  // The library is one file; split it by how much of it each kind of content takes.
  final raw = await b.load('assets/data/library.json');
  final data = jsonDecode(utf8.decode(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes)))
      as Map<String, dynamic>;
  var words = 0, sentences = 0, examples = 0, nWords = 0, nSentences = 0, nExamples = 0;
  for (final e in (data['entries'] as List).cast<Map<String, dynamic>>()) {
    final ex = e['examples'] as List? ?? const [];
    final exBytes = ex.isEmpty ? 0 : utf8.encode(jsonEncode(ex)).length;
    final all = utf8.encode(jsonEncode(e)).length;
    examples += exBytes;
    nExamples += ex.length;
    if (e['kind'] == 'sentence') {
      sentences += all - exBytes;
      nSentences++;
    } else {
      words += all - exBytes;
      nWords++;
    }
  }
  final total = words + sentences + examples;
  int share(int n) => total == 0 ? 0 : (raw.lengthInBytes * n / total).round();
  parts.add(StoragePart('Words and phrases', '$nWords entries with pinyin, meanings and notes', share(words)));
  parts.add(StoragePart('Phrasebook sentences', '$nSentences sentences', share(sentences)));
  parts.add(StoragePart('Example sentences', '$nExamples examples shown on word pages', share(examples)));

  // Studio audio, from the sizes the audio tool records.
  var audio = 0, clips = 0;
  try {
    final manifest = jsonDecode(await b.loadString('assets/audio/manifest.json')) as Map<String, dynamic>;
    for (final c in ((manifest['clips'] as Map?) ?? const {}).values) {
      clips++;
      audio += ((c as Map)['bytes'] as int?) ?? 0;
    }
  } catch (_) {}
  parts.add(StoragePart(
    'Recorded audio',
    clips == 0 ? 'Not added yet, so the phone\'s own voice is used' : '$clips clips',
    audio,
  ));

  var licences = 0;
  for (final f in const ['CC-BY-SA-4.0.txt', 'complete-hsk-vocabulary-MIT.txt']) {
    try {
      licences += (await b.load('assets/licenses/$f')).lengthInBytes;
    } catch (_) {}
  }
  parts.add(StoragePart('Licences and credits', 'Full licence texts for the sources', licences));

  return parts;
}

/// The learner's own data, measured now.
StoragePart progressStorage(UserStore store) => StoragePart(
      'Your progress',
      '${store.starred.length} starred, ${store.cards.length} cards practised, ${store.reviews.length} answers logged',
      store.sizeBytes,
    );

String formatBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(n < 10 * 1024 ? 1 : 0)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
}
