import 'dart:math';

import 'package:flutter/material.dart';

import '../data/adapt.dart';
import '../data/daily.dart';
import '../data/journey.dart';
import '../data/library.dart';
import '../data/say_it.dart';
import '../data/today.dart';
import '../data/user_store.dart';
import '../data/week_steps.dart';
import '../models/entry.dart';
import '../models/journey_week.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'patterns_screen.dart';
import 'practice_home.dart';
import 'practice_screen.dart';
import 'adapt_widgets.dart';
import 'say_it_screen.dart';
import 'week_day_screen.dart';
import 'wide.dart';
import 'word_web.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Day of the week, 0 for Monday, of [now] in a week starting [start].
int dayIndex(JourneyWeek w, DateTime now) => (dayNumber(now) - dayNumber(w.start)).clamp(0, 6);

String _skillTitle(String skill) => skill == 'cards' ? 'Flashcards' : practiceType(skill).title;

/// Opens what day [day] of [week] is for.
void openDay(BuildContext context, JourneyWeek week, int day) {
  final scope = AppScope.of(context);
  final plan = dayPlan(week, day, skillTitle: _skillTitle(week.skill));
  final lib = scope.library;
  if (plan.kind == DayKind.meet) scope.store.starAll(plan.ids);
  final steps = daySteps(scope.store, week, day, DateTime.now());
  if (steps != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WeekDayScreen(week: week, day: day, steps: steps)));
    return;
  }
  Widget screen;
  switch (plan.kind) {
    case DayKind.meet:
      // Met words are starred (above), so their cards come back for review.
      screen = PracticeScreen(ids: plan.ids, includeNotDue: true);
    case DayKind.practise:
      screen = PracticeScreen(ids: plan.ids, includeNotDue: true);
    case DayKind.skill:
      screen = skillScreen(lib, week);
    case DayKind.sentences:
      final ss = sayItListFor(lib, week, DayKind.sentences) ?? const <Entry>[];
      screen = ss.isEmpty
          ? PracticeScreen(ids: week.words, includeNotDue: true)
          : SayItScreen(entries: ss, sentences: true, carryOn: true);
    case DayKind.recap:
      screen = RecapScreen(week: week);
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// The week's practice type, on the week's words where it can be.
Widget skillScreen(Library lib, JourneyWeek week) {
  final words = [for (final id in week.words) ?lib.byId[id]];
  switch (week.skill) {
    case 'speak':
      // Say it is hard work: never more than [hardCap] words a day.
      return SayItScreen(entries: words.take(hardCap).toList(), carryOn: true);
    case 'build':
      final p = lib.patterns.where((p) => p.id == week.pattern).firstOrNull;
      return BuildSentenceScreen(only: p);
    default:
      return practiceType(week.skill).open();
  }
}

/// The top of Practice when the journey is on: this week's theme, its days and
/// today's step. When the journey hasn't been offered yet, a short invitation.
class WeekCard extends StatelessWidget {
  const WeekCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(listenable: scope.store, builder: (context, _) => _build(context, scope.library, scope.store));
  }

  Widget _build(BuildContext context, Library lib, UserStore store) {
    final theme = Theme.of(context);
    if (!store.journeyOn) {
      if (store.journeyAsked) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New: your learning journey', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('A focus each week that grows from the words you already know. Learning anything else, any time, '
                  'still counts.'),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JourneyStartScreen())),
                    child: const Text('Have a look'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => store.setJourneyOn(false), child: const Text('Not now')),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final week = store.weekAt(now);
    final known = knownWords(lib, store).length;
    final m = milestoneFor(known);
    final banners = <Widget>[
      if (m > store.milestoneSeen)
        _Banner(Icons.emoji_events_outlined, 'Milestone reached: ${milestones[m - 1]} words',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MilestoneScreen(milestone: m)))),
      if (store.recapPending case final key?)
        if (store.weeks.where((w) => dayKey(w.start) == key).firstOrNull case final last?)
          _Banner(Icons.history, 'Last week\'s recap: ${last.title}',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecapScreen(week: last, finished: true)))),
    ];
    if (week == null) {
      return Column(children: [
        ...banners,
        const Card(
          margin: EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ListTile(title: Text('Planning this week…')),
        ),
      ]);
    }
    final day = dayIndex(week, now);
    final plan = dayPlan(week, day, skillTitle: _skillTitle(week.skill));
    final steps = daySteps(store, week, day, now);
    final nextStep = steps == null ? null : nextStepIndex(store, week, day, steps, now);
    final number = store.weeks.indexOf(week) + 1;
    final metSet = metIn(store, week);
    final met = metSet.length;
    final unmet = [for (final id in week.words) if (!metSet.contains(id)) id];
    // How far today's Say it list has got, so the button can carry on.
    final list = sayItListFor(lib, week, plan.kind);
    final progress = list == null ? null : sayItCarryOn(store, list, now);
    final aim = plan.kind == DayKind.sentences ? min(sentenceAim(week), list?.length ?? 0) : (list?.length ?? 0);
    final found = foundBetween(lib, store, week.start, now.add(const Duration(minutes: 1)), except: week.words.toSet());
    final goal = store.dailyGoal;
    final perDay = lastDays(store.reviews, now, days: day + 1);
    return Column(
      children: [
        ...banners,
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          color: theme.colorScheme.secondaryContainer,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeekScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('THIS WEEK · WEEK $number · ${pathNames[week.path]!.toUpperCase()}',
                            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  Text(week.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(week.why, style: theme.textTheme.bodySmall),
                  for (final note in [?week.levelNote, ...?week.adapt?.notes])
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(note, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            children: [
                              Icon(
                                i < day
                                    ? (perDay[i].$2 >= goal ? Icons.circle : (perDay[i].$2 > 0 ? Icons.adjust : Icons.circle_outlined))
                                    : (i == day ? Icons.radio_button_checked : Icons.circle_outlined),
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              Text(_days[i].substring(0, 1), style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('$met of ${week.words.length} words met',
                            textAlign: TextAlign.end, style: theme.textTheme.labelMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${_days[day]}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: steps == null ? '${plan.title}. ${plan.detail}.' : plan.title),
                  ])),
                  if (steps != null) ...[
                    const SizedBox(height: 4),
                    StepList(week: week, day: day, steps: steps, dense: true),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: (progress.at / aim).clamp(0, 1).toDouble()),
                    const SizedBox(height: 2),
                    Text(
                        progress.at >= aim
                            ? '${progress.at} said today. Aim reached, and you can keep going'
                            : '${progress.at} of $aim said today',
                        style: theme.textTheme.labelMedium),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(steps != null
                          ? (nextStep == null
                              ? 'Done today: go again'
                              : nextStep == 0 && stepDone(store, week, day, 0, steps[0], now).isEmpty
                                  ? 'Start: ${steps[0].kind.title}'
                                  : 'Carry on: step ${nextStep + 1} of ${steps.length}')
                          : progress == null || progress.at == 0
                          ? plan.title
                          : progress.at >= progress.queue.length
                              ? '${plan.title}: all done, start again'
                              : 'Carry on from ${progress.at + 1}'),
                      onPressed: () => openDay(context, week, day),
                    ),
                  ),
                  // Started mid-week, or missed the first days: the words come first.
                  if (plan.kind != DayKind.meet && !week.isReview && unmet.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.style_outlined),
                        label: Text('Meet the ${unmet.length} words you haven\'t yet'),
                        onPressed: () {
                          AppScope.of(context).store.starAll(unmet);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => store.weekMix
                                  ? MeetScreen(ids: unmet)
                                  : PracticeScreen(ids: unmet, includeNotDue: true)));
                        },
                      ),
                    ),
                  if (found.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Found yourself this week: ${found.length}', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in found.take(8))
                          ActionChip(
                            label: Text(lib.byId[id]!.simplified),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(lib.byId[id]!))),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.icon, this.text, this.onTap);
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: ListTile(leading: Icon(icon), title: Text(text), trailing: const Icon(Icons.chevron_right), onTap: onTap),
      );
}

/// This week: its focus, its words and a plan for each day.
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final now = DateTime.now();
        final week = store.weekAt(now);
        if (week == null) return Scaffold(appBar: AppBar(title: const Text('This week')));
        final today = dayIndex(week, now);
        final perDay = lastDays(store.reviews, now, days: today + 1);
        final pattern = lib.patterns.where((p) => p.id == week.pattern).firstOrNull;
        final practised = metIn(store, week);
        Widget fact(String label, String value) => Expanded(
              child: Card(
                margin: const EdgeInsets.all(3),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(label, style: theme.textTheme.labelSmall), Text(value, style: theme.textTheme.titleSmall)],
                  ),
                ),
              ),
            );
        return Scaffold(
          appBar: AppBar(
            title: const Text('This week'),
            actions: [
              TextButton(
                onPressed: () => showSwap(context, week),
                child: const Text('Swap'),
              ),
            ],
          ),
          body: Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(week.title, style: theme.textTheme.headlineSmall),
                      Text(week.why),
                      for (final note in [?week.levelNote, ...?week.adapt?.notes])
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(note, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  fact('Path', pathNames[week.path]!),
                  fact('Words', '${week.words.length}'),
                ]),
                Row(children: [
                  fact(pattern != null ? 'Pattern' : (week.char != null ? 'Family' : 'Topic'),
                      pattern?.name ?? week.char ?? (week.topic == null ? 'Mixed' : topicLabel(week.topic!))),
                  fact('Practice to lean on', _skillTitle(week.skill)),
                ]),
                const SizedBox(height: 12),
                Text('Days', style: theme.textTheme.titleSmall),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < 7; i++)
                        () {
                          final p = dayPlan(week, i, skillTitle: _skillTitle(week.skill));
                          final steps = daySteps(store, week, i, now);
                          final done = i < today && perDay[i].$2 >= store.dailyGoal;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              done ? Icons.check_circle : (i == today ? Icons.radio_button_checked : Icons.circle_outlined),
                              color: theme.colorScheme.primary,
                            ),
                            title: Text('${_days[i]}  ${p.title}', style: TextStyle(fontWeight: i == today ? FontWeight.bold : null)),
                            subtitle: Text(steps == null
                                ? p.detail
                                : steps.map((s) => s.extra == null ? s.kind.short : '${s.kind.short} (extra)').join(' · ')),
                            onTap: () => openDay(context, week, i),
                          );
                        }(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text('Any day can be done any time. Missed days don\'t matter: the plan just carries on. '
                      'Words you meet are starred so their cards come back for review.', style: theme.textTheme.bodySmall),
                ),
                Row(
                  children: [
                    Expanded(child: Text('The week\'s words', style: theme.textTheme.titleSmall)),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add words'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CloseScreen())),
                    ),
                  ],
                ),
                for (final id in week.words)
                  if (lib.byId[id] case final e?)
                    Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      clipBehavior: Clip.antiAlias,
                      child: EntryTile(e,
                          trailingNote: practised.contains(id) ? const Icon(Icons.check, size: 18) : null),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Offers other weeks to switch to (this week) or to pick for next week.
Future<void> showSwap(BuildContext context, JourneyWeek week, {bool next = false}) async {
  final scope = AppScope.of(context);
  final options = weekOptions(scope.library, scope.store, week.start, count: 4)
      .where((w) => w.title != week.title)
      .take(3)
      .toList();
  final pick = await showModalBottomSheet<JourneyWeek>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(next ? 'Pick next week' : 'Swap this week for', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final w in options)
            ListTile(
              title: Text(w.title),
              subtitle: Text('${pathNames[w.path]} · ${w.why}'),
              onTap: () => Navigator.pop(context, w),
            ),
        ],
      ),
    ),
  );
  if (pick != null) await scope.store.startWeek(pick);
}

/// Words that link to many the learner knows, each with why, and sentences
/// they are one word away from reading.
class CloseScreen extends StatefulWidget {
  const CloseScreen({super.key});

  @override
  State<CloseScreen> createState() => _CloseScreenState();
}

class _CloseScreenState extends State<CloseScreen> {
  String _filter = 'connections';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final now = DateTime.now();
        final week = store.journeyOn ? store.weekAt(now) : null;
        final c = Connections(lib, store);
        final skip = {...?week?.words};
        final topic = week?.topic ?? 'food';
        final ch = week?.char ?? (c.yourByChar.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length))).firstOrNull?.key;
        final level = lib.levels.firstWhere(
            (l) => lib.entries.any((e) => e.hsk == l && !e.isSentence && !c.yours.contains(e.id)),
            orElse: () => lib.levels.last);
        final list = switch (_filter) {
          'topic' => c.suggestions(where: (e) => e.topics.contains(topic), skip: skip),
          'characters' when ch != null => c.suggestions(where: (e) => e.simplified.contains(ch), skip: skip),
          'hsk' => c.suggestions(where: (e) => e.hsk == level, skip: skip, any: true),
          _ => c.suggestions(skip: skip),
        };
        final almost = c.almostReadable(limit: 5);
        return Scaffold(
          appBar: AppBar(title: const Text('Close to what you know')),
          body: Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                      week == null
                          ? 'Words that link to lots of what you already have. Tap + to star one.'
                          : 'Words that link to lots of what you already have. Tap + to add one to this week.',
                      style: theme.textTheme.bodySmall),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (k, label) in [
                      ('connections', 'Connections'),
                      ('topic', topicLabel(topic)),
                      if (ch != null) ('characters', '$ch family'),
                      ('hsk', 'HSK $level gaps'),
                    ])
                      ChoiceChip(label: Text(label), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
                  ],
                ),
                const SizedBox(height: 8),
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nothing left here. Try another chip.')),
                for (final s in list) _SuggestionTile(s, week: week),
                if (almost.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Almost readable', style: theme.textTheme.titleSmall),
                  Text('Phrasebook sentences where you have every word but one.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  for (final a in almost)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(a.sentence))),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.sentence.simplified, style: theme.textTheme.titleLarge),
                              Text(a.sentence.gloss),
                              const SizedBox(height: 4),
                              Text('Missing: ${a.missing.simplified} ${a.missing.pinyin} · ${a.missing.meanings.first}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile(this.s, {this.week});
  final Suggestion s;
  final JourneyWeek? week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context).store;
    final w = week;
    final added = w != null ? w.words.contains(s.entry.id) : store.isStarred(s.entry.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(s.entry))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              SizedBox(width: 72, child: HanziText(s.entry, style: theme.textTheme.titleLarge)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.entry.pinyin} · ${s.entry.meanings.first}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    ReasonChips(s.reasons),
                  ],
                ),
              ),
              IconButton(
                tooltip: added ? 'Added' : (w != null ? 'Add to this week' : 'Star'),
                icon: Icon(added ? Icons.check_circle : Icons.add_circle_outline, color: theme.colorScheme.primary),
                onPressed: added
                    ? null
                    : () => w != null ? store.addToWeek(w.start, s.entry.id) : store.toggleStar(s.entry.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted labels, one per reason.
class ReasonChips extends StatelessWidget {
  const ReasonChips(this.reasons, {super.key});
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final r in reasons)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
            child: Text(r, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          ),
      ],
    );
  }
}

/// How a week went, and next week to pick.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key, required this.week, this.finished = false});
  final JourneyWeek week;

  /// The week is over (and the next one has already started).
  final bool finished;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppScope.of(context).store, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final sum = summarise(lib, store, week, now);
    final sentences = sentenceResults(lib, store, week.start, DateTime(week.start.year, week.start.month, week.start.day + 7));
    final current = store.weekAt(now);
    // A finished week: offer to swap the week that started without a choice.
    // Otherwise: pick next week.
    final nextStart = finished && current != null ? current.start : DateTime(week.start.year, week.start.month, week.start.day + 7);
    final options = weekOptions(lib, store, nextStart);
    final picked = finished ? current : store.nextWeek;
    Widget stat(String label, String value, [String? note]) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(3),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  Text(value, style: theme.textTheme.headlineSmall),
                  if (note != null) Text(note, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
    if (finished && store.recapPending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.recapSeen());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Week recap')),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(week.title, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: 8),
            Row(children: [
              stat('Planned words met', '${sum.met}', 'of ${sum.planned}'),
              stat('Found yourself', '${sum.found.length}'),
            ]),
            Row(children: [
              stat('Answers', '${sum.answers}', 'on ${sum.days} ${sum.days == 1 ? 'day' : 'days'}'),
              stat('Right', sum.checked == 0 ? '–' : '${sum.percentRight}%', 'checked by the app'),
            ]),
            if (sentences.said > 0)
              Row(children: [
                stat('Sentences understood', '${sentences.right} of ${sentences.said}',
                    'by the recogniser, a guide. Under 40% makes next week\'s easier, over 80% harder'),
              ]),
            if (methodResults(store, week) case final results when results.length >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                    'Went best: ${methodLabel(results.first.$1)} (${percent(results.first)}% right). '
                    'Needs work: ${methodLabel(results.last.$1)} (${percent(results.last)}% right).',
                    style: theme.textTheme.bodyMedium),
              ),
            if (flashcardResults(store, week) case (final remembered, final cards) when cards > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                    'Flashcards: you marked $remembered of $cards as remembered (Again counts as not). '
                    'Your own marks, so they are kept apart from the scores above.',
                    style: theme.textTheme.bodySmall),
              ),
            if (sum.found.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final id in sum.found.take(12)) Chip(label: Text(lib.byId[id]!.simplified), visualDensity: VisualDensity.compact),
                ]),
              ),
            NextWeekPanel(week: week, nextStart: nextStart, finished: finished),
            const SizedBox(height: 16),
            Text(finished ? 'This week' : 'Pick next week', style: theme.textTheme.titleMedium),
            Text(
                finished
                    ? 'This week started with the first one below. Tap another to switch.'
                    : 'If you don\'t pick, the first one starts on Monday.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            for (final (i, w) in options.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: picked?.title == w.title || (picked == null && i == 0)
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2), borderRadius: BorderRadius.circular(12))
                    : null,
                child: ListTile(
                  title: Text(w.title),
                  subtitle: Text('${pathNames[w.path]} · ${w.why}'),
                  trailing: i == 0 ? const Chip(label: Text('Suggested'), visualDensity: VisualDensity.compact) : null,
                  onTap: () async {
                    finished ? await store.startWeek(w) : await store.setNextWeek(w);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The moment a milestone is reached: the new colour and what's ready now.
class MilestoneScreen extends StatelessWidget {
  const MilestoneScreen({super.key, required this.milestone});
  final int milestone;

  static const _ready = [
    'Key sounds and Say it suit short words like these.',
    'Build the sentence and Pairs & scales have enough of your words to work with.',
    'Phrasebook sentences open up: try the Sentences days and Almost readable.',
    'Longer sentences: Say it with sentences, and the Characters path.',
    'Most phrasebook sentences are within reach.',
    'You can read most of the library. HSK 5 and 6 are in Settings.',
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final theme = Theme.of(context);
    final colour = milestoneColors[milestone];
    final c = Connections(scope.library, store);
    final web = wordWeb(c, max: 1);
    final found = foundBetween(scope.library, store, DateTime(2000), DateTime.now().add(const Duration(minutes: 1)),
        except: {for (final w in store.weeks) ...w.words});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.milestoneSeen < milestone) store.setMilestoneSeen(milestone);
    });
    return Scaffold(
      appBar: AppBar(),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(8)),
                  child: Text('$milestone', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Milestone $milestone reached', style: theme.textTheme.labelLarge),
                      Text('${milestones[milestone - 1]} words, all your own', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('On to ${milestoneNames[milestone < milestoneNames.length ? milestone : milestoneNames.length - 1]}.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (web.isNotEmpty) Text('Your biggest cluster is ${web.first.hanzi}, with ${web.first.words.length} of your words.'),
            Text('${found.length} of your words came from exploring on your own, outside the weekly plans.'),
            const SizedBox(height: 16),
            Text('New colour', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Container(height: 14, color: milestoneColors[milestone - 1].withValues(alpha: 0.35))),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: Container(height: 14, color: colour)),
            ]),
            if (!store.milestoneColours)
              Text('Milestone colours are off in Settings, so the app stays blue.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Ready for you now'),
                subtitle: Text(_ready[milestone - 1]),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context)
                ..pop()
                ..push(MaterialPageRoute(builder: (_) => const WordWebScreen())),
              child: const Text('See your word web'),
            ),
          ],
        ),
      ),
    );
  }
}

/// First look at the journey: where the learner is now, the pace, and start.
class JourneyStartScreen extends StatelessWidget {
  const JourneyStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final known = knownWords(lib, store).length;
        final yours = yourWords(lib, store).length;
        final m = milestoneFor(known);
        final nextAt = m < milestones.length ? milestones[m] : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Your learning journey')),
          body: Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const Text('Each week the app suggests a small set of words that link to ones you already have: '
                    'characters you know, sentences you can almost read, words about the same things. '
                    'Anything you learn on your own still counts, and can become next week\'s focus.'),
                const SizedBox(height: 12),
                Card(
                  color: milestoneColors[m].withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WHERE YOU ARE NOW', style: theme.textTheme.labelSmall),
                        Text(m == 0 ? 'Starting out' : 'Milestone $m · ${milestones[m - 1]} words',
                            style: theme.textTheme.titleLarge),
                        Text('You know $known words, and have $yours starred or practised.'),
                        if (nextAt != null) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: known / nextAt, color: milestoneColors[m]),
                          Text('Next milestone at $nextAt words', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const JourneySettings(),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await store.setJourneyOn(true, milestone: m);
                    await ensureWeek(lib, store, DateTime.now());
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(store.journeyOn ? 'Done' : 'Start this week'),
                ),
                if (!store.journeyOn)
                  TextButton(
                    onPressed: () async {
                      await store.setJourneyOn(false);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Not now, keep things as they are'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The journey's settings: paths, pace, review weeks and colours.
class JourneySettings extends StatelessWidget {
  const JourneySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How weeks are chosen', style: theme.textTheme.titleSmall),
        Text('Weeks take turns between the paths switched on.', style: theme.textTheme.bodySmall),
        for (final p in pathDescriptions.keys)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(pathNames[p]!),
            subtitle: Text(pathDescriptions[p]!),
            value: store.journeyPaths.contains(p),
            onChanged: (v) => store.setJourneyPath(p, v),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('New words a week'),
          trailing: DropdownButton<int>(
            value: store.journeyPace,
            onChanged: (v) => store.setJourneyPace(v!),
            items: [
              for (final (n, l) in const [(10, 'Gentle · 10'), (20, 'Steady · 20'), (35, 'Keen · 35')])
                DropdownMenuItem(value: n, child: Text(l)),
              if (![10, 20, 35].contains(store.journeyPace))
                DropdownMenuItem(value: store.journeyPace, child: Text('${store.journeyPace}')),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Adjust to how I\'m doing'),
          subtitle: Text(store.adaptOn
              ? 'Small steps each week, with the reason on the recap.'
                  '${store.weeks.lastOrNull?.adapt?.pace == null ? '' : ' Now ${store.weeks.last.adapt!.pace} new words a week'}'
              : 'Off: the same new words every week, and the usual practice'),
          value: store.adaptOn,
          onChanged: store.setAdaptOn,
        ),
        if (store.adaptOn) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Never fewer than'),
            trailing: DropdownButton<int>(
              value: store.paceMin,
              onChanged: (v) => store.setPaceLimits(least: v),
              items: [for (final n in {4, 6, 8, 10, 15, store.paceMin}.toList()..sort()) DropdownMenuItem(value: n, child: Text('$n words'))],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Never more than'),
            trailing: DropdownButton<int>(
              value: store.paceMax,
              onChanged: (v) => store.setPaceLimits(most: v),
              items: [for (final n in {20, 25, 30, 40, 50, store.paceMax}.toList()..sort()) DropdownMenuItem(value: n, child: Text('$n words'))],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ask how the week felt'),
            subtitle: const Text('On the week recap. Your answer counts more than the numbers'),
            value: store.askFeel,
            onChanged: store.setAskFeel,
          ),
          Text('Choosing new words a week yourself starts the adjusting again from there.', style: theme.textTheme.bodySmall),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Review week'),
          subtitle: const Text('A week with no new words'),
          trailing: DropdownButton<int>(
            value: store.reviewEvery,
            onChanged: (v) => store.setReviewEvery(v!),
            items: const [
              DropdownMenuItem(value: 3, child: Text('Every 3rd week')),
              DropdownMenuItem(value: 4, child: Text('Every 4th week')),
              DropdownMenuItem(value: 6, child: Text('Every 6th week')),
              DropdownMenuItem(value: 0, child: Text('Never')),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mix practice types into week days'),
          subtitle: const Text('Meet, see, hear and say the week\'s words. Off: mostly flashcards, as before'),
          value: store.weekMix,
          onChanged: store.setWeekMix,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('New colour at each milestone'),
          subtitle: const Text('Off keeps the usual blue'),
          value: store.milestoneColours,
          onChanged: store.setMilestoneColours,
        ),
      ],
    );
  }
}

/// The Settings page for the journey.
class JourneySettingsScreen extends StatelessWidget {
  const JourneySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Learning journey')),
        body: Readable(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Plan my weeks'),
                subtitle: const Text('Off goes back to free practice. Your word web keeps growing either way.'),
                value: store.journeyOn,
                onChanged: (v) async {
                  final lib = AppScope.of(context).library;
                  await store.setJourneyOn(v, milestone: milestoneFor(knownWords(lib, store).length));
                  if (v) await ensureWeek(lib, store, DateTime.now());
                },
              ),
              const Divider(),
              const JourneySettings(),
            ],
          ),
        ),
      ),
    );
  }
}

/// On a word's page: how it links to the learner's words, and ways to grow from it.
class ConnectionsCard extends StatelessWidget {
  const ConnectionsCard(this.entry, {super.key});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.isSentence) return const SizedBox.shrink();
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    final theme = Theme.of(context);
    final c = Connections(lib, store);
    final lines = <String>[];
    for (final ch in chars(entry.simplified)) {
      final mine = [for (final id in c.yourByChar[ch] ?? const <String>[]) if (id != entry.id) lib.byId[id]!.simplified];
      if (mine.isEmpty) continue;
      final more = mine.length > 2 ? ' and ${mine.length - 2} more' : '';
      lines.add('$ch is in ${mine.take(2).join(', ')}$more');
    }
    final sentences = c.sentencesWith(entry.id).length;
    final reasons = c.yours.contains(entry.id) ? const <String>[] : c.score(entry).reasons;
    final linked = [
      for (final r in entry.related)
        if (c.yours.contains(r.id)) lib.byId[r.id]!.simplified,
    ];
    if (lines.isEmpty && reasons.isEmpty && linked.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final week = store.journeyOn ? store.weekAt(now) : null;
    final inWeek = week?.words.contains(entry.id) ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How it connects to your words', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final l in lines) Text(l),
              if (linked.isNotEmpty) Text('Linked to ${linked.take(3).join(', ')}'),
              if (sentences > 0) Text('Used in $sentences phrasebook ${sentences == 1 ? 'sentence' : 'sentences'}'),
              if (reasons.isNotEmpty) ...[const SizedBox(height: 4), ReasonChips(reasons)],
              if (store.journeyOn) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (week != null)
                      OutlinedButton(
                        onPressed: inWeek ? null : () => store.addToWeek(week.start, entry.id),
                        child: Text(inWeek ? 'In this week' : 'Add to this week'),
                      ),
                    FilledButton.tonal(
                      onPressed: () async {
                        final start = week == null ? mondayOf(now) : DateTime(week.start.year, week.start.month, week.start.day + 7);
                        final w = planWeek(lib, store, start, 'connections', seed: entry.id);
                        if (w != null) await store.setNextWeek(w);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Next week will grow from ${entry.simplified}')));
                        }
                      },
                      child: Text(store.nextWeek?.seed == entry.id ? 'Next week grows from this' : 'Grow next week from this'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

int percent((String, int, int) r) => (100 * r.$2 / r.$3).round();

/// What a logged practice method is called on screen.
String methodLabel(String method) => switch (method) {
      'cards' => 'Flashcards',
      'listen' => 'Hear it, pick the word',
      'meaning' => 'See it, pick the meaning',
      'reverse' => 'See the meaning, pick the word',
      'pinyin' => 'See it, pick the pinyin',
      'type' => 'Type the pinyin',
      'order' => 'Pairs & scales',
      'speak' => 'Say it',
      'tones' => 'Key sounds',
      'build' => 'Build the sentence',
      _ => method,
    };
