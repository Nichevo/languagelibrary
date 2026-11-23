import 'dart:math';

import 'package:flutter/material.dart';

import '../data/journey.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'entry_tile.dart';
import 'journey_screens.dart';
import 'wide.dart';

/// At the top of Progress: the milestone colour, words known and the way into
/// the word web.
class JourneySummaryCard extends StatelessWidget {
  const JourneySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final known = knownWords(scope.library, scope.store).length;
    final m = milestoneFor(known);
    final nextAt = m < milestones.length ? milestones[m] : null;
    final from = m == 0 ? 0 : milestones[m - 1];
    final colour = milestoneColors[m];
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WordWebScreen())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(8)),
                child: m == 0
                    ? const Icon(Icons.eco_outlined, color: Colors.white)
                    : Text('$m', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m == 0 ? 'Starting out' : 'Milestone $m · ${milestoneNames[m - 1]}', style: theme.textTheme.titleMedium),
                    Text(nextAt == null ? '$known words known' : '$known words known · next milestone at $nextAt'),
                    if (nextAt != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: (known - from) / (nextAt - from), color: colour),
                    ],
                    const SizedBox(height: 4),
                    Text('Open your word web', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The learner's own words as a map: clusters around the characters they
/// share, known words solid, words being learned lighter, and a few dotted
/// words that would join next.
class WordWebScreen extends StatefulWidget {
  const WordWebScreen({super.key});

  @override
  State<WordWebScreen> createState() => _WordWebScreenState();
}

class _WordWebScreenState extends State<WordWebScreen> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final lib = scope.library;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final c = Connections(lib, store);
        final web = wordWeb(c);
        final known = c.known.length;
        final m = milestoneFor(known);
        final colour = milestoneColors[m];
        final coverage = hskCoverage(lib, c.known);
        final offList = c.known.where((id) => lib.byId[id]!.hsk == null).length;
        final layout = WebLayout(web, c.known);
        return Scaffold(
          appBar: AppBar(title: const Text('Your word web')),
          body: Readable(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                Text('${c.yours.length} of your words · $known known', style: theme.textTheme.titleMedium),
                Text('Grouped by the characters they share. Tap a cluster to see its words.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                if (web.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Your web starts once you have a few words that share a character. '
                          'Star or practise some words and come back.'),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        onTapUp: (d) {
                          final hit = layout.hit(d.localPosition, box.biggest);
                          if (hit != null) _openCluster(context, hit);
                        },
                        child: CustomPaint(
                          size: box.biggest,
                          painter: WebPainter(layout, colour: colour, theme: theme),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 12, children: [
                  _legend(theme, colour, 'known', filled: true),
                  _legend(theme, colour.withValues(alpha: 0.35), 'learning', filled: true),
                  _legend(theme, theme.colorScheme.outline, 'could join next', filled: false),
                ]),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Milestones', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        for (var i = 0; i < milestones.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: known >= milestones[i] ? milestoneColors[i + 1] : null,
                                  border: Border.all(color: milestoneColors[i + 1], width: 2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${milestones[i]} words · ${milestoneNames[i]}')),
                              if (known >= milestones[i]) const Icon(Icons.check, size: 16),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Measured against HSK, for interest', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        for (final (level, k, all) in coverage)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              SizedBox(width: 56, child: Text('HSK $level')),
                              Expanded(child: LinearProgressIndicator(value: all == 0 ? 0 : k / all, color: colour)),
                              SizedBox(width: 80, child: Text('$k of $all', textAlign: TextAlign.end)),
                            ]),
                          ),
                        const SizedBox(height: 4),
                        Text('Known words on no HSK list: $offList', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.hub_outlined),
                  label: const Text('Words close to what you know'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CloseScreen())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legend(ThemeData theme, Color c, String label, {required bool filled}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: filled ? c : null,
              shape: BoxShape.circle,
              border: filled ? null : Border.all(color: c),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      );

  void _openCluster(BuildContext context, Cluster cl) {
    final scope = AppScope.of(context);
    final lib = scope.library;
    final store = scope.store;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) {
          final theme = Theme.of(context);
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              Text('${cl.hanzi} · ${cl.words.length} of your words', style: theme.textTheme.titleLarge),
              if (store.journeyOn)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final now = DateTime.now();
                      final week = store.weekAt(now);
                      final start = week == null ? mondayOf(now) : DateTime(week.start.year, week.start.month, week.start.day + 7);
                      final fam = planWeek(lib, store, start, 'characters', char: cl.hanzi);
                      if (fam != null) await store.setNextWeek(fam);
                      if (context.mounted) Navigator.pop(context);
                      messenger.showSnackBar(SnackBar(
                          content: Text(fam == null ? 'No new words left in the ${cl.hanzi} family' : 'Next week: the ${cl.hanzi} family')));
                    },
                    child: Text('Make next week the ${cl.hanzi} family'),
                  ),
                ),
              if (cl.next.isNotEmpty) ...[
                Text('Could join next', style: theme.textTheme.titleSmall),
                for (final s in cl.next)
                  Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text('${s.entry.simplified}  ${s.entry.pinyin}'),
                      subtitle: Text(s.entry.meanings.first),
                      trailing: ReasonChips(s.reasons.take(1).toList()),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(s.entry))),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Text('Your words', style: theme.textTheme.titleSmall),
              for (final id in cl.words)
                Card(margin: const EdgeInsets.only(bottom: 4), clipBehavior: Clip.antiAlias, child: EntryTile(lib.byId[id]!)),
            ],
          );
        },
      ),
    );
  }
}

/// Where the clusters and their words sit, in a unit square.
class WebLayout {
  WebLayout(this.clusters, this.known) {
    final n = clusters.length;
    for (var i = 0; i < n; i++) {
      // The biggest in the middle, the rest round it.
      final at = i == 0 && n > 1
          ? const Offset(0.5, 0.5)
          : () {
              final k = n > 1 ? i - 1 : 0;
              final ring = n > 1 ? n - 1 : 1;
              final a = -pi / 2 + 2 * pi * k / ring;
              final r = n > 1 ? 0.31 : 0.0;
              return Offset(0.5 + r * cos(a), 0.5 + r * sin(a));
            }();
      hubs.add(at);
    }
    final biggest = clusters.isEmpty ? 1 : clusters.map((c) => c.words.length).reduce(max);
    for (var i = 0; i < n; i++) {
      final cl = clusters[i];
      hubRadius.add(0.035 + 0.03 * sqrt(cl.words.length / biggest));
      final spots = <(Offset, bool, String)>[];
      final count = min(cl.words.length, 40);
      for (var j = 0; j < count; j++) {
        // Golden-angle spiral round the hub.
        final a = j * 2.39996;
        final r = hubRadius[i] + 0.02 + 0.012 * sqrt(j + 1) * 2.2;
        spots.add((hubs[i] + Offset(r * cos(a), r * sin(a)), known.contains(cl.words[j]), cl.words[j]));
      }
      dots.add(spots);
      final far = hubRadius[i] + 0.02 + 0.012 * sqrt(count + 1) * 2.2 + 0.035;
      next.add([
        for (var j = 0; j < cl.next.length; j++)
          hubs[i] + Offset(far * cos(-pi / 2 + j * 0.9 + i), far * sin(-pi / 2 + j * 0.9 + i)),
      ]);
    }
  }

  final List<Cluster> clusters;
  final Set<String> known;
  final hubs = <Offset>[];
  final hubRadius = <double>[];
  final dots = <List<(Offset, bool, String)>>[];
  final next = <List<Offset>>[];

  /// The cluster at [p] in a canvas of [size], if any.
  Cluster? hit(Offset p, Size size) {
    final u = Offset(p.dx / size.width, p.dy / size.height);
    var best = -1;
    var bestD = 0.12;
    for (var i = 0; i < hubs.length; i++) {
      final d = (hubs[i] - u).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best < 0 ? null : clusters[best];
  }
}

class WebPainter extends CustomPainter {
  WebPainter(this.layout, {required this.colour, required this.theme});
  final WebLayout layout;
  final Color colour;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset u) => Offset(u.dx * size.width, u.dy * size.height);
    final s = size.shortestSide;
    final line = Paint()
      ..color = colour.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final dash = Paint()
      ..color = theme.colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Links between clusters that share words (a word in two clusters' characters).
    for (var i = 1; i < layout.hubs.length; i++) {
      canvas.drawLine(at(layout.hubs[0]), at(layout.hubs[i]), line);
    }
    for (var i = 0; i < layout.clusters.length; i++) {
      final hub = at(layout.hubs[i]);
      for (final (p, isKnown, _) in layout.dots[i]) {
        canvas.drawLine(hub, at(p), line);
        canvas.drawCircle(at(p), s * 0.011, Paint()..color = isKnown ? colour : colour.withValues(alpha: 0.35));
      }
      for (final p in layout.next[i]) {
        canvas.drawCircle(at(p), s * 0.013, dash);
      }
      canvas.drawCircle(hub, s * layout.hubRadius[i], Paint()..color = colour);
      final tp = TextPainter(
        text: TextSpan(
          text: layout.clusters[i].hanzi,
          style: TextStyle(color: Colors.white, fontSize: s * layout.hubRadius[i] * 1.1, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, hub - Offset(tp.width / 2, tp.height / 2));
      final count = TextPainter(
        text: TextSpan(text: '${layout.clusters[i].words.length}', style: theme.textTheme.labelSmall),
        textDirection: TextDirection.ltr,
      )..layout();
      count.paint(canvas, hub + Offset(-count.width / 2, s * layout.hubRadius[i] + 1));
    }
  }

  @override
  bool shouldRepaint(WebPainter old) => old.layout != layout || old.colour != colour || old.theme != theme;
}
