import 'package:flutter/material.dart';

import '../data/journey.dart';
import '../data/week_steps.dart';
import '../models/entry.dart';
import '../models/journey_week.dart';
import 'common.dart';
import 'drill_screen.dart';
import 'practice_screen.dart';
import 'say_it_screen.dart';
import 'wide.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

IconData stepIcon(StepKind k) => switch (k) {
  StepKind.meet => Icons.waving_hand_outlined,
  StepKind.meaning => Icons.visibility_outlined,
  StepKind.listen => Icons.hearing,
  StepKind.recall => Icons.checklist,
  StepKind.mixed => Icons.shuffle,
  StepKind.type => Icons.keyboard,
  StepKind.cards => Icons.style_outlined,
  StepKind.dueCards => Icons.style_outlined,
  StepKind.sayIt => Icons.mic_none,
};

/// The steps of a mixed week day as a bar of segments with their short names,
/// for under a step screen's title. [at] is the step showing.
class StepBar extends StatelessWidget implements PreferredSizeWidget {
  const StepBar({super.key, required this.steps, required this.at, required this.complete});
  final List<DayStep> steps;
  final int at;

  /// Which steps are finished today.
  final List<bool> complete;

  @override
  Size get preferredSize => const Size.fromHeight(34);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (final (i, s) in steps.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: complete[i]
                          ? c.primary
                          : i == at
                          ? c.primary.withValues(alpha: 0.45)
                          : c.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.kind.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: i == at ? FontWeight.bold : null,
                      color: i == at ? c.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A mixed week day: its steps, one after another. Opening it starts the
/// first step not done today; finishing a step goes straight on to the next.
/// Leaving a step part way comes back here, and the day carries on from there.
class WeekDayScreen extends StatefulWidget {
  const WeekDayScreen({super.key, required this.week, required this.day, required this.steps});
  final JourneyWeek week;
  final int day;
  final List<DayStep> steps;

  @override
  State<WeekDayScreen> createState() => _WeekDayScreenState();
}

class _WeekDayScreenState extends State<WeekDayScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final store = AppScope.of(context).store;
    final next = nextStepIndex(store, widget.week, widget.day, widget.steps, DateTime.now());
    if (next != null) WidgetsBinding.instance.addPostFrameCallback((_) => _run(next));
  }

  List<bool> _complete() {
    final store = AppScope.of(context).store;
    final now = DateTime.now();
    return [for (final (i, s) in widget.steps.indexed) stepComplete(store, widget.week, widget.day, i, s, now)];
  }

  Future<void> _run(int i) async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    final step = widget.steps[i];
    final now = DateTime.now();
    final key = stepKey(widget.week, widget.day, i, now);
    final complete = _complete();
    // Carry on with the words not done yet, or all of them once the step is done.
    final done = stepDone(store, widget.week, widget.day, i, step, now);
    final left = complete[i]
        ? step.ids
        : [
            for (final id in step.ids)
              if (!done.contains(id)) id,
          ];
    final ids = left.toSet().toList();
    void wordDone(String id) => store.markStepDone(key, id);
    final bar = StepBar(steps: widget.steps, at: i, complete: complete);
    final later = [
      for (var j = i + 1; j < widget.steps.length; j++)
        if (!complete[j]) j,
    ];
    final nextLabel = later.isEmpty ? 'Finish the day' : 'Next: ${widget.steps[later.first].kind.title}';
    final title = step.kind.title;
    final Widget screen = switch (step.kind) {
      StepKind.meet => MeetScreen(ids: ids, stepBar: bar, onWordDone: wordDone, nextLabel: nextLabel),
      StepKind.meaning => DrillScreen(
        drill: Drill.listen,
        ids: ids,
        kind: Choice.meaning,
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.listen => DrillScreen(
        drill: Drill.listen,
        ids: ids,
        kind: Choice.listen,
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.recall => DrillScreen(
        drill: Drill.listen,
        ids: ids,
        // Every other word of the week each way.
        kinds: {
          for (final (j, id) in widget.week.words.indexed) id: j.isEven ? Choice.reverse.name : Choice.pinyin.name,
        },
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.mixed => DrillScreen(
        drill: Drill.listen,
        ids: ids,
        kinds: mixedKinds(
          store,
          widget.week,
          step.ids,
          now,
          canOrder: (id) => lib.byId[id] != null && scaleToOrder(lib, lib.byId[id]!) != null,
        ),
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.type => DrillScreen(
        drill: Drill.type,
        ids: ids,
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.cards => PracticeScreen(
        ids: ids,
        includeNotDue: true,
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.dueCards => PracticeScreen(
        ids: step.ids,
        title: title,
        stepBar: bar,
        onWordDone: wordDone,
        nextLabel: nextLabel,
      ),
      StepKind.sayIt => SayItScreen(entries: [for (final id in step.ids) ?lib.byId[id]], carryOn: true, stepBar: bar),
    };
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() {});
    // Finished with the button at the end (Say it has none): straight on.
    final finished = result == true || (step.kind == StepKind.sayIt && _complete()[i]);
    if (!finished) return;
    final next = nextStepIndex(store, widget.week, widget.day, widget.steps, DateTime.now());
    if (next != null && next != i) _run(next);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final plan = dayPlan(widget.week, widget.day);
    return Scaffold(
      appBar: AppBar(title: Text('${_dayNames[widget.day]}: ${plan.title}')),
      body: Readable(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final now = DateTime.now();
            final next = nextStepIndex(store, widget.week, widget.day, widget.steps, now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'One step after another, each a short round on the day\'s words. '
                    'A word you get wrong comes back at the end of its round.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                StepList(week: widget.week, day: widget.day, steps: widget.steps, onTap: _run),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: next == null
                      ? Text(
                          'All done for today. Any step can be done again.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        )
                      : FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            next == 0 && stepDone(store, widget.week, widget.day, 0, widget.steps[0], now).isEmpty
                                ? 'Start'
                                : 'Carry on: step ${next + 1} of ${widget.steps.length}',
                          ),
                          onPressed: () => _run(next),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A mixed day's steps with how far each has got today.
class StepList extends StatelessWidget {
  const StepList({
    super.key,
    required this.week,
    required this.day,
    required this.steps,
    this.onTap,
    this.dense = false,
  });
  final JourneyWeek week;
  final int day;
  final List<DayStep> steps;
  final void Function(int step)? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final next = nextStepIndex(store, week, day, steps, now);
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          () {
            final complete = stepComplete(store, week, day, i, s, now);
            final count = s.kind == StepKind.dueCards
                ? (complete ? 'none due' : '${dueAmong(store, s.ids, now)} due')
                : '${stepDone(store, week, day, i, s, now).length}/${s.ids.toSet().length}';
            final icon = Icon(
              complete ? Icons.check_circle : (i == next ? Icons.radio_button_checked : Icons.circle_outlined),
              size: dense ? 18 : 22,
              color: theme.colorScheme.primary,
            );
            if (dense) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.kind.title,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: i == next ? FontWeight.bold : null),
                      ),
                    ),
                    Text(count, style: theme.textTheme.labelMedium),
                  ],
                ),
              );
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: icon,
                title: Text(s.kind.title, style: TextStyle(fontWeight: i == next ? FontWeight.bold : null)),
                subtitle: Text(count),
                trailing: Icon(stepIcon(s.kind)),
                onTap: onTap == null ? null : () => onTap!(i),
              ),
            );
          }(),
      ],
    );
  }
}

/// "Meet each word": one new word at a time, with its sound, an example and
/// the words you have that share a character.
class MeetScreen extends StatefulWidget {
  const MeetScreen({super.key, required this.ids, this.stepBar, this.onWordDone, this.nextLabel});
  final List<String> ids;
  final PreferredSizeWidget? stepBar;
  final void Function(String id)? onWordDone;
  final String? nextLabel;

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  int _at = 0;
  List<Entry>? _words;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words != null) return;
    final lib = AppScope.of(context).library;
    _words = [for (final id in widget.ids) ?lib.byId[id]];
    _playSoon();
  }

  void _playSoon() => WidgetsBinding.instance.addPostFrameCallback((_) => _play());

  void _play({bool? slow}) {
    if (!mounted || _at >= _words!.length) return;
    final scope = AppScope.of(context);
    scope.speaker.play(_words![_at], female: scope.store.femaleVoice, slow: slow ?? scope.store.slowAudio);
  }

  void _next() {
    widget.onWordDone?.call(_words![_at].id);
    setState(() => _at++);
    _playSoon();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final words = _words!;
    final done = _at >= words.length;
    return Scaffold(
      appBar: AppBar(title: Text(StepKind.meet.title), bottom: widget.stepBar),
      body: Readable(
        child: done
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        words.isEmpty
                            ? 'No new words here.'
                            : 'You\'ve met ${words.length} ${words.length == 1 ? 'word' : 'words'}.',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(widget.nextLabel ?? 'Done'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    children: [
                      Text('Word ${_at + 1} of ${words.length}', style: theme.textTheme.bodySmall),
                      Expanded(child: _card(context, words[_at], scope, theme)),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _next,
                          child: Text(_at + 1 < words.length ? 'Next word' : 'Done meeting'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _card(BuildContext context, Entry e, AppScope scope, ThemeData theme) {
    final c = Connections(scope.library, scope.store);
    final links = <String>[];
    for (final ch in chars(e.simplified)) {
      final mine = [
        for (final id in c.yourByChar[ch] ?? const <String>[])
          if (id != e.id && !widget.ids.contains(id)) scope.library.byId[id]!.simplified,
      ];
      if (mine.isNotEmpty) links.add('$ch is in ${mine.take(3).join(', ')}, which you have');
    }
    final example = e.examples.firstOrNull;
    return ListView(
      children: [
        const SizedBox(height: 16),
        HanziText(
          e,
          style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        PinyinText(
          e,
          style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(e.gloss, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(tooltip: 'Play again', icon: const Icon(Icons.volume_up), onPressed: _play),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.slow_motion_video),
              label: const Text('Slow'),
              onPressed: () => _play(slow: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (example != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(example.zh, style: theme.textTheme.titleMedium),
                  Text(example.pinyin, style: theme.textTheme.bodySmall),
                  Text(example.en, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        for (final l in links.take(2))
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(l, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}
