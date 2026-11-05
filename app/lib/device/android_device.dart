import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/daily.dart';
import '../data/library.dart';
import '../data/user_store.dart';
import '../models/entry.dart';
import 'device.dart';

/// The real phone: notifications, widgets and the system file dialogs.
class AndroidDevice implements Device {
  final _notes = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<String>.broadcast();
  bool _ready = false;

  /// Widget providers in android/app/src/main/kotlin.
  static const _widgets = ['WordOfDayWidget', 'DueWidget', 'FocusCardWidget'];
  static const _channel = AndroidNotificationDetails(
    'daily_reminder',
    'Daily reminder',
    channelDescription: 'One reminder a day when flashcards are due',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const _reminderDays = 14;
  static const _widgetDays = 31;

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<String?> start() async {
    String? first;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _notes.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) => _opened.add(r.payload ?? 'practice'),
      );
      final launch = await _notes.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) first = launch!.notificationResponse?.payload ?? 'practice';
      _ready = true;
    } catch (_) {
      // Reminders stay off if the phone refuses; the rest of the app still works.
    }
    try {
      first ??= _place(await HomeWidget.initiallyLaunchedFromHomeWidget());
      HomeWidget.widgetClicked.listen((uri) {
        final p = _place(uri);
        if (p != null) _opened.add(p);
      });
    } catch (_) {}
    return first;
  }

  /// langlib://practice -> 'practice'
  /// langlib://entry/abc -> 'entry/abc'
  String? _place(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return null;
    return uri.pathSegments.isEmpty ? uri.host : '${uri.host}/${uri.pathSegments.first}';
  }

  Timer? _debounce;

  /// Waits a moment so a burst of changes (a study session) refreshes once.
  @override
  Future<void> refresh(Library library, UserStore store) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      final now = DateTime.now();
      await _scheduleReminders(store, now);
      await _updateWidgets(library, store, now);
    });
  }

  Future<void> _scheduleReminders(UserStore store, DateTime now) async {
    if (!_ready) return;
    try {
      await _notes.cancelAll();
      if (!store.reminderOn) return;
      for (final (day, due) in dueByDay(store, now, days: _reminderDays)) {
        if (due == 0) continue;
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, store.reminderMinutes ~/ 60,
            store.reminderMinutes % 60);
        if (!at.isAfter(tz.TZDateTime.now(tz.local))) continue;
        await _notes.zonedSchedule(
          id: day.difference(DateTime(2024)).inDays,
          title: due == 1 ? '1 card is due' : '$due cards are due',
          body: 'About ${(due * 0.4).ceil()} minutes. Tap to start practising.',
          scheduledDate: at,
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'practice',
        );
      }
    } catch (_) {}
  }

  Future<void> _updateWidgets(Library library, UserStore store, DateTime now) async {
    Map<String, String> word(Entry e) => {
          'hz': e.simplified,
          'tones': toneDigits(e),
          'py': e.pinyin,
          'en': e.gloss,
          'id': e.id,
        };
    final today = dayOf(now);
    final words = [
      for (var i = 0; i < _widgetDays; i++)
        if (wordOfTheDay(library, today.add(Duration(days: i))) case final e?)
          {'d': dayKey(today.add(Duration(days: i))), ...word(e)},
    ];
    final due = [
      for (final (day, n) in dueByDay(store, now, days: _widgetDays)) {'d': dayKey(day), 'n': n},
    ];
    final focus = [
      for (final id in store.starred.reversed.take(80))
        if (library.byId[id] case final e?)
          {...word(e), 'level': store.difficulty[id]?.label ?? ''},
    ];
    try {
      await HomeWidget.saveWidgetData<String>('wotd', jsonEncode(words));
      await HomeWidget.saveWidgetData<String>('due', jsonEncode(due));
      await HomeWidget.saveWidgetData<String>('focus', jsonEncode(focus));
      await HomeWidget.saveWidgetData<bool>('toneHanzi', store.toneHanzi);
      for (final w in _widgets) {
        await HomeWidget.updateWidget(androidName: w);
      }
    } catch (_) {}
  }

  @override
  Future<bool> allowNotifications() async {
    try {
      final android = _notes.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> saveFile(String name, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save backup',
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> openFile() async {
    final f = await FilePicker.pickFile(dialogTitle: 'Open a backup');
    return f?.readAsBytes();
  }
}
