import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/speaker.dart';
import 'data/library.dart';
import 'data/user_store.dart';
import 'device/device.dart';
import 'device/native_device.dart';
import 'sync/dropbox_sync.dart';
import 'ui/common.dart';
import 'ui/entry_screen.dart';
import 'ui/focus_screen.dart';
import 'ui/learn_screen.dart';
import 'ui/library_screen.dart';
import 'ui/practice_home.dart';
import 'ui/scales_screen.dart';
import 'ui/stats_screen.dart';
import 'ui/wide.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDataLicenses();
  final library = await Library.load();
  final store = await UserStore.open();
  final Device device = !kIsWeb && (Platform.isAndroid || Platform.isIOS) ? NativeDevice() : NoDevice();
  final openedAt = await device.start();
  final sync = await DropboxSync.open();
  runApp(LanguageLibraryApp(
    library: library,
    store: store,
    speaker: Speaker(library),
    device: device,
    sync: sync,
    openedAt: openedAt,
  ));
}

/// Adds the data licenses to Flutter's built-in license page.
void _registerDataLicenses() {
  const files = {
    'CC-CEDICT (CC BY-SA 4.0)': 'assets/licenses/CC-BY-SA-4.0.txt',
    'complete-hsk-vocabulary (MIT)': 'assets/licenses/complete-hsk-vocabulary-MIT.txt',
    'WordNet (Princeton University)': 'assets/licenses/WordNet-license.txt',
    'sherpa-onnx Chinese speech model (Apache 2.0)': 'assets/licenses/Apache-2.0.txt',
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

class LanguageLibraryApp extends StatefulWidget {
  const LanguageLibraryApp({
    super.key,
    required this.library,
    required this.store,
    required this.speaker,
    required this.device,
    this.sync,
    this.openedAt,
  });

  final Library library;
  final UserStore store;
  final Speaker speaker;
  final Device device;
  final DropboxSync? sync;

  /// Where a widget or the reminder opened the app, e.g. 'practice'.
  final String? openedAt;

  @override
  State<LanguageLibraryApp> createState() => _LanguageLibraryAppState();
}

class _LanguageLibraryAppState extends State<LanguageLibraryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_changed);
    widget.device.refresh(widget.library, widget.store);
    _sync();
  }

  /// Brings in progress from the other device when the app opens or comes
  /// back, and sends this device's when it is put away. Only when Dropbox is linked.
  void _sync() => widget.sync?.sync(widget.store);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_changed);
    super.dispose();
  }

  /// Stars, scores and studied cards change the reminder and the widgets.
  void _changed() => widget.device.refresh(widget.library, widget.store);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have started while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      widget.device.refresh(widget.library, widget.store);
      _sync();
    }
    if (state == AppLifecycleState.paused) _sync();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1565C0);
    return AppScope(
      library: widget.library,
      store: widget.store,
      speaker: widget.speaker,
      device: widget.device,
      sync: widget.sync,
      child: MaterialApp(
        title: 'Language Library',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
        home: HomeShell(openedAt: widget.openedAt),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.openedAt});

  final String? openedAt;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<String>? _sub;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _sub = AppScope.of(context).device.opened.listen(_go);
    if (widget.openedAt != null) WidgetsBinding.instance.addPostFrameCallback((_) => _go(widget.openedAt!));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 'library', 'learn', 'focus', 'practice', 'progress', `entry/ID` or `scale/N` from a widget.
  void _go(String place) {
    if (!mounted) return;
    if (place.startsWith('scale/')) {
      final scales = AppScope.of(context).library.scales;
      final n = int.tryParse(place.substring(6)) ?? -1;
      setState(() => _tab = 0);
      if (n >= 0 && n < scales.length) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScaleScreen(scales[n])));
      }
      return;
    }
    if (place.startsWith('entry/')) {
      final e = AppScope.of(context).library.byId[place.substring(6)];
      setState(() => _tab = 0);
      if (e != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(e)));
      return;
    }
    final tab = const {'library': 0, 'learn': 1, 'focus': 2, 'practice': 3, 'progress': 4}[place];
    if (tab != null) setState(() => _tab = tab);
  }

  static const _places = [
    (Icons.menu_book_outlined, Icons.menu_book, 'Library'),
    (Icons.lightbulb_outline, Icons.lightbulb, 'Learn'),
    (Icons.star_outline, Icons.star, 'Focus'),
    (Icons.style_outlined, Icons.style, 'Practice'),
    (Icons.insights_outlined, Icons.insights, 'Progress'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _tab,
      children: const [LibraryScreen(), LearnScreen(), FocusScreen(), PracticeHome(), StatsScreen()],
    );
    if (isWide(context)) {
      // iPad in landscape and other big screens: the tabs go down the left side.
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                destinations: [
                  for (final (icon, selected, label) in _places)
                    NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final (icon, _, label) in _places) NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}

@visibleForTesting
Widget appForTest(Library library, UserStore store, {Device? device, DropboxSync? sync}) => LanguageLibraryApp(
    library: library, store: store, speaker: Speaker(library), device: device ?? NoDevice(), sync: sync);
