import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/ui/pairs_practice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  final lib = loadRealLibrary();

  test('a session mixes scales and opposites, each opposite with one right answer', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    final qs = pairsSession(lib, store.shows, Random(4), count: 10);
    expect(qs.length, 10);
    expect(qs.whereType<OrderItem>().length, 5);
    for (final q in qs.whereType<OppositeItem>()) {
      expect(q.options.length, 4);
      expect(q.options.where((o) => o.id == q.answer.id).length, 1);
      expect(q.options.map((o) => o.simplified).toSet().length, 4);
      final pair = lib.opposites.firstWhere((p) => {p.a.id, p.b.id}.containsAll([q.word.id, q.answer.id]));
      expect(q.english, pair.a.id == q.word.id ? pair.aEnglish : pair.bEnglish);
    }
  });

  testWidgets('Practice tab opens Pairs & scales and answers a question', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(lib, store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pairs & scales'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Pairs & scales'));
    await tester.pumpAndSettle();
    expect(find.text('Put in order'), findsOneWidget);
    await tester.tap(find.text('Drag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    // A wrong check gives a hint. Unless that hint left one word to place
    // (which finishes it), the question waits: nothing logged, no Next yet.
    expect(find.text('Hint 1'), findsOneWidget);
    if (find.text('Show answer').evaluate().isNotEmpty) {
      expect(find.text('Next'), findsNothing);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
    }
    expect(store.reviews.last.method, 'order');
    // The finished answer stays on screen, marked place by place, until Next.
    expect(find.textContaining(RegExp('Here is the order.|In order, with')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the opposite'), findsOneWidget);
  });
}
