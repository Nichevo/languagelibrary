import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/ui/learn_screen.dart';
import 'package:language_library/ui/practice_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

/// Opens every tab, every Learn section and every practice type at iPad sizes,
/// so a layout that overflows or breaks on a big (or short) screen fails here.
void main() {
  const sizes = {
    'iPad landscape': Size(1366, 1024),
    'iPad portrait': Size(820, 1180),
    'iPad mini landscape': Size(1133, 744),
  };

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: every page opens without layout errors', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = await UserStore.open();
      final lib = loadRealLibrary();
      for (final e in lib.entries.where((e) => !e.isSentence).take(12)) {
        await store.toggleStar(e.id);
      }
      await tester.pumpWidget(appForTest(lib, store));
      await tester.pumpAndSettle();

      Future<void> visit(String label) async {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name: $label');
      }

      Future<void> back() async {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      for (final tab in ['Library', 'Learn', 'Focus', 'Practice', 'Progress']) {
        await visit(tab);
      }

      await visit('Learn');
      for (final s in learnSections) {
        await visit(s.title);
        await back();
      }

      await visit('Practice');
      for (final t in practiceTypes) {
        await tester.ensureVisible(find.text(t.subtitle));
        await tester.pumpAndSettle();
        await visit(t.subtitle);
        await back();
      }
    });
  }
}
