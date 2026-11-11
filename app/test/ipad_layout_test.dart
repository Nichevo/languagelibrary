import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_library/data/user_store.dart';
import 'package:language_library/main.dart';
import 'package:language_library/ui/entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic_test.dart' show loadRealLibrary;

void main() {
  Future<UserStore> openApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await UserStore.open();
    await tester.pumpWidget(appForTest(loadRealLibrary(), store));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('iPad in landscape: side rail, word list beside the word page', (tester) async {
    await openApp(tester, const Size(1366, 1024));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // A word is already showing beside the list.
    expect(find.byType(EntryScreen), findsOneWidget);

    // Tapping a word shows it in the right pane instead of opening a new page.
    await tester.enterText(find.byType(TextField), 'nihao');
    await tester.pumpAndSettle();
    await tester.tap(find.text('你好').first);
    await tester.pumpAndSettle();
    expect(find.byType(EntryScreen), findsOneWidget);
    expect(find.text('Female voice'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: 'the list is still there');

    // The rail switches tabs.
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('iPad in portrait keeps the bottom tabs and opens words as pages', (tester) async {
    await openApp(tester, const Size(820, 1180));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(EntryScreen), findsNothing);
  });
}
