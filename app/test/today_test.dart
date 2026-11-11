import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/today.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/srs/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  Review r(DateTime at, [String method = 'cards']) =>
      Review(at, const Duration(seconds: 5), Rating.good, false, method: method);
  List<Review> many(DateTime day, int n, [String method = 'cards']) =>
      [for (var i = 0; i < n; i++) r(day.add(Duration(minutes: i)), method)];

  final now = DateTime(2026, 11, 11, 18);
  DateTime ago(int d) => DateTime(2026, 11, 11 - d, 9);

  test('answers today and the last seven days', () {
    final reviews = [...many(ago(0), 3), ...many(ago(2), 5), ...many(ago(9), 4)];
    expect(answersOn(reviews, now), 3);
    final week = lastDays(reviews, now);
    expect(week.length, 7);
    expect(week.last, (DateTime(2026, 11, 11), 3));
    expect(week[4], (DateTime(2026, 11, 9), 5));
    expect(week.first.$1, DateTime(2026, 11, 5));
  });

  test('a streak counts today only once the goal is met', () {
    final past = [...many(ago(1), 20), ...many(ago(2), 25), ...many(ago(4), 30)];
    expect(streak(past, 20, now), 2); // yesterday and the day before; a gap on day 3
    expect(streak([...past, ...many(ago(0), 5)], 20, now), 2);
    expect(streak([...past, ...many(ago(0), 20)], 20, now), 3);
    expect(streak(many(ago(2), 20), 20, now), 0);
  });

  test('next step: due cards first, then the least-used practice', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    expect(nextStep(store, now), isA<TryType>().having((t) => t.method, 'method', 'build'));
    store.reviews.addAll([...many(ago(1), 3, 'build'), ...many(ago(2), 2, 'tones'), ...many(ago(3), 1, 'opposite')]);
    expect(nextStep(store, now), isA<TryType>().having((t) => t.method, 'method', 'order').having((t) => t.lastWeek, 'n', 1));
    store.reviews.addAll(many(ago(10), 9, 'order')); // too long ago to count
    expect((nextStep(store, now) as TryType).method, 'order');
  });

  testWidgets('Practice shows the Today card; the goal is set in Settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appForTest(loadRealLibrary(), store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('0 of 20 answers today'), findsOneWidget);
    expect(find.text('Build the sentence'), findsWidgets);

    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    expect(store.dailyGoal, 10);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('0 of 10 answers today'), findsOneWidget);
  });
}
