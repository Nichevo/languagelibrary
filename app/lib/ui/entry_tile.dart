import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'wide.dart';

/// One row in the Library or Focus list: hanzi, pinyin, English, star.
class EntryTile extends StatelessWidget {
  const EntryTile(this.entry, {super.key, this.trailingNote});

  final Entry entry;
  final Widget? trailingNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picker = EntryPicker.maybeOf(context);
    final tile = entry.isSentence ? _sentence(context, theme) : _word(context, theme);
    if (picker?.selected != entry.id) return tile;
    return Material(color: theme.colorScheme.secondaryContainer, child: tile);
  }

  /// Opens the word, or shows it in the other pane on a wide screen.
  void _open(BuildContext context) {
    final picker = EntryPicker.maybeOf(context);
    if (picker != null) {
      picker.onPick(entry);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(entry)));
    }
  }

  Widget _word(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HanziText(entry, style: theme.textTheme.titleLarge),
                  PinyinText(entry, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.gloss, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (trailingNote != null) ...[const SizedBox(height: 4), trailingNote!],
                ],
              ),
            ),
            DifficultyBadge(entry.id),
            StarButton(entry),
          ],
        ),
      ),
    );
  }

  Widget _sentence(BuildContext context, ThemeData theme) => InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HanziText(entry, style: theme.textTheme.titleLarge),
                    PinyinText(entry, style: theme.textTheme.bodySmall),
                    Text(entry.gloss),
                    if (trailingNote != null) ...[const SizedBox(height: 4), trailingNote!],
                  ],
                ),
              ),
              DifficultyBadge(entry.id),
              StarButton(entry),
            ],
          ),
        ),
      );
}
