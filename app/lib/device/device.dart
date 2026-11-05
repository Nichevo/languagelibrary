import 'dart:async';
import 'dart:typed_data';

import '../data/library.dart';
import '../data/user_store.dart';

/// Phone features outside the app's own screens: the daily reminder, the
/// home-screen widgets, and saving or opening a backup file.
abstract class Device {
  /// Where the app was opened from a widget or the reminder: 'practice', 'focus' or 'library'.
  Stream<String> get opened;

  /// Call once at start. Returns the place the app was opened at, if any.
  Future<String?> start();

  /// Reschedule the reminder and refresh the widgets from the current data.
  Future<void> refresh(Library library, UserStore store);

  /// Ask for permission to show notifications. True if allowed.
  Future<bool> allowNotifications();

  /// Let the person pick where to save [bytes]. True if saved.
  Future<bool> saveFile(String name, Uint8List bytes);

  /// Let the person pick a file to open, or null if they cancel.
  Future<Uint8List?> openFile();
}

/// Does nothing. Used in tests and on platforms without these features.
class NoDevice implements Device {
  NoDevice();

  final saved = <String, Uint8List>{};
  Uint8List? nextOpen;
  int refreshes = 0;
  final _opened = StreamController<String>.broadcast();

  void open(String where) => _opened.add(where);

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<String?> start() async => null;

  @override
  Future<void> refresh(Library library, UserStore store) async => refreshes++;

  @override
  Future<bool> allowNotifications() async => true;

  @override
  Future<bool> saveFile(String name, Uint8List bytes) async {
    saved[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> openFile() async => nextOpen;
}
