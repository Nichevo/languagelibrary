import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/speaker.dart';
import 'data/library.dart';
import 'data/user_store.dart';
import 'ui/common.dart';
import 'ui/focus_screen.dart';
import 'ui/library_screen.dart';
import 'ui/practice_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDataLicenses();
  final library = await Library.load();
  final store = await UserStore.open();
  runApp(LanguageLibraryApp(library: library, store: store, speaker: Speaker(library)));
}

/// Adds the data licenses to Flutter's built-in license page.
void _registerDataLicenses() {
  const files = {
    'CC-CEDICT (CC BY-SA 4.0)': 'assets/licenses/CC-BY-SA-4.0.txt',
    'complete-hsk-vocabulary (MIT)': 'assets/licenses/complete-hsk-vocabulary-MIT.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: path) in files.entries) {
      try {
        yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(path));
      } catch (_) {
        // license file missing: run tools/fetch_licenses.py
      }
    }
  });
}

class LanguageLibraryApp extends StatelessWidget {
  const LanguageLibraryApp({super.key, required this.library, required this.store, required this.speaker});

  final Library library;
  final UserStore store;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1565C0);
    return AppScope(
      library: library,
      store: store,
      speaker: speaker,
      child: MaterialApp(
        title: 'Language Library',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [LibraryScreen(), FocusScreen(), PracticeHome()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.star_outline), label: 'Focus'),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Practice'),
        ],
      ),
    );
  }
}

@visibleForTesting
Widget appForTest(Library library, UserStore store) =>
    LanguageLibraryApp(library: library, store: store, speaker: Speaker(library));
