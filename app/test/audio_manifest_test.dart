import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/library.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.manifest);
  final Map<String, dynamic> manifest;

  @override
  Future<ByteData> load(String key) async {
    final bytes = key == 'assets/audio/manifest.json'
        ? utf8.encode(jsonEncode(manifest))
        : File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  test('clips that failed the check are never played', () async {
    final lib = await Library.load(_Bundle({
      'clips': {
        'a_f': {'file': 'a_f.mp3', 'check': 'exact'},
        'a_m': {'file': 'a_m.mp3', 'check': 'sounds-same'},
        'b_f': {'file': 'b_f.mp3', 'check': 'mismatch'},
      },
    }));
    expect(lib.audioFiles.keys, unorderedEquals(['a_f', 'a_m']));
  });
}
