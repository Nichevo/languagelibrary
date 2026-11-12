import 'package:flutter/material.dart';

import '../data/today.dart';
import '../srs/scheduler.dart';
import 'common.dart';
import 'drill_screen.dart';
import 'pairs_practice.dart';
import 'patterns_screen.dart';
import 'practice_screen.dart';
import 'say_it_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';
import 'wide.dart';

class PracticeHome extends StatelessWidget {
  const PracticeHome({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice'), actions: const [SettingsButton()]),
      body: Readable(child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          const sched = Scheduler();
          int due(String? list) => store
              .idsIn(list)
              .expand((id) => Direction.values.map((d) => store.card(id, d)))
              .where((c) => sched.isDue(c, now))
              .length;

          Widget listTile(String title, String? list) {
            final count = store.idsIn(list).length;
            final d = due(list);
            return ListTile(
              leading: const Icon(Icons.style),
              title: Text(title),
              subtitle: Text('$count words · $d cards due'),
              trailing: const Icon(Icons.chevron_right),
              enabled: count > 0,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => switch (store.practiceMode) {
                  'listen' => DrillScreen(drill: Drill.listen, list: list),
                  'type' => DrillScreen(drill: Drill.type, list: list),
                  _ => PracticeScreen(list: list, includeNotDue: d == 0),
                },
              )),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const TodayCard(),
              const _Heading('Flashcards'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cards', icon: Icon(Icons.style_outlined), label: Text('Cards')),
                    ButtonSegment(value: 'listen', icon: Icon(Icons.checklist), label: Text('Choose')),
                    ButtonSegment(value: 'type', icon: Icon(Icons.keyboard), label: Text('Type')),
                  ],
                  selected: {store.practiceMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => store.setPracticeMode(s.single),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(switch (store.practiceMode) {
                  'listen' => 'Pick the right answer from four. It doesn\'t change your flashcard schedule.',
                  'type' => 'See a word and type its pinyin. It doesn\'t change your flashcard schedule.',
                  _ => 'Each word has two cards: Chinese → English and English → Chinese.',
                }),
              ),
              if (store.practiceMode == 'listen')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: Choice.fromSetting(store.choiceKind) == null ? 'mix' : store.choiceKind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder(), isDense: true),
                    onChanged: (v) => store.setChoiceKind(v!),
                    items: [
                      for (final c in Choice.pickable) DropdownMenuItem(value: c.name, child: Text(c.label)),
                      const DropdownMenuItem(value: 'mix', child: Text('Mix them up, with scales to put in order')),
                    ],
                  ),
                ),
              listTile('All starred words', null),
              for (final name in store.lists.keys) listTile(name, name),
              const _Heading('More ways to practise'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.6,
                  children: [
                    for (final t in practiceTypes) _TypeTile(t),
                  ],
                ),
              ),
            ],
          );
        },
      )),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// A practice type on the Practice tab's grid.
class PracticeType {
  const PracticeType(this.method, this.title, this.subtitle, this.icon, this.open);
  final String method, title, subtitle;
  final IconData icon;
  final Widget Function() open;
}

final practiceTypes = <PracticeType>[
  PracticeType('build', 'Build the sentence', 'Chinese word order', Icons.view_week_outlined,
      () => const BuildSentenceScreen()),
  PracticeType('tones', 'Tricky sounds', 'Hear it, pick the tone', Icons.hearing, () => const ToneQuizScreen()),
  PracticeType('order', 'Pairs & scales', 'Order and opposites', Icons.swap_vert, () => const PairsPracticeScreen()),
  PracticeType('speak', 'Say it', 'Speak and see what it heard', Icons.mic_none, () => const SayItScreen()),
];

PracticeType practiceType(String method) => practiceTypes.firstWhere((t) => t.method == method);

class _TypeTile extends StatelessWidget {
  const _TypeTile(this.type);
  final PracticeType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => type.open())),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(type.icon, color: theme.colorScheme.primary),
              const Spacer(),
              Text(type.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(type.subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top of Practice: today's answers against the daily goal, the streak,
/// the last seven days, and one button for what to do next.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppScope.of(context).store, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final done = answersOn(store.reviews, now);
    final goal = store.dailyGoal;
    final days = streak(store.reviews, goal, now);
    final week = lastDays(store.reviews, now);
    final step = nextStep(store, now);
    final met = done >= goal;
    final (label, detail) = switch (step) {
      DueCards(:final count) => ('Review $count due ${count == 1 ? 'card' : 'cards'}', 'Flashcards first, while they are due.'),
      TryType(:final method, :final lastWeek) => (
          practiceType(method).title,
          lastWeek == 0 ? 'No cards due. You haven\'t tried this in the last week.' : 'No cards due. Your least-used practice this week.'
        ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Today', style: theme.textTheme.titleLarge)),
                if (days > 0)
                  Text('$days ${days == 1 ? 'day' : 'days'} in a row',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(met ? '$done answers today. Goal of $goal reached!' : '$done of $goal answers today',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (done / goal).clamp(0, 1).toDouble(), minHeight: 8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (d, n) in week)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(n >= goal ? Icons.circle : (n > 0 ? Icons.adjust : Icons.circle_outlined),
                            size: 14, color: theme.colorScheme.primary),
                        Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].elementAt(d.weekday - 1),
                            style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(detail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(label),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => switch (step) {
                    DueCards() => const PracticeScreen(),
                    TryType(:final method) => practiceType(method).open(),
                  },
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
