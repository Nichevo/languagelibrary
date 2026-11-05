import 'package:flutter/material.dart';

import '../audio/speaker.dart';
import '../data/library.dart';
import '../data/user_store.dart';
import '../models/entry.dart';

/// Gives every screen the library, the learner's data and the speaker.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.library,
    required this.store,
    required this.speaker,
    required super.child,
  });

  final Library library;
  final UserStore store;
  final Speaker speaker;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      library != old.library || store != old.store || speaker != old.speaker;
}

/// The same colour for a tone everywhere in the app, so tones become visual.
Color toneColor(int tone, Brightness b) {
  final dark = b == Brightness.dark;
  switch (tone) {
    case 1:
      return dark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F);
    case 2:
      return dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    case 3:
      return dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    case 4:
      return dark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2);
    default:
      return dark ? const Color(0xFFBDBDBD) : const Color(0xFF616161);
  }
}

/// Pinyin with each syllable in its tone colour. Uses written (dictionary) tones.
class PinyinText extends StatelessWidget {
  const PinyinText(this.entry, {super.key, this.style, this.textAlign});

  final Entry entry;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final spans = <TextSpan>[];
    final words = entry.pinyin.split(' ');
    if (entry.isSentence && words.length == entry.syllables.length) {
      // Sentences keep their capital letter and punctuation.
      for (var i = 0; i < words.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: ' '));
        spans.add(TextSpan(text: words[i], style: TextStyle(color: toneColor(entry.syllables[i].tone, b))));
      }
      return Text.rich(TextSpan(children: spans, style: style), textAlign: textAlign);
    }
    for (final s in entry.syllables) {
      final isErhua = s.pinyin == 'r';
      if (spans.isNotEmpty && !isErhua) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(text: s.pinyin, style: TextStyle(color: toneColor(s.tone, b))));
    }
    return Text.rich(TextSpan(children: spans, style: style), textAlign: textAlign);
  }
}

class StarButton extends StatelessWidget {
  const StarButton(this.entry, {super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = store.isStarred(entry.id);
        return IconButton(
          tooltip: on ? 'Remove from Focus list' : 'Add to Focus list',
          icon: Icon(on ? Icons.star : Icons.star_border,
              color: on ? Theme.of(context).colorScheme.primary : null),
          onPressed: () => store.toggleStar(entry.id),
        );
      },
    );
  }
}

String topicLabel(String t) => switch (t) {
      'everyday' => 'Everyday',
      'food' => 'Food',
      'travel' => 'Travel',
      'family' => 'Family',
      'love' => 'Love',
      'numbers' => 'Numbers',
      _ => t,
    };

/// Small "Hard" / "OK" / "Easy" tag for a word the learner has scored.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = store.difficulty[id];
        if (d == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final color = switch (d) {
          Difficulty.hard => scheme.error,
          Difficulty.ok => scheme.tertiary,
          Difficulty.easy => scheme.primary,
        };
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(d.label, style: TextStyle(fontSize: 11, color: color)),
        );
      },
    );
  }
}
