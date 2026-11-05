import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'common.dart';
import 'entry_screen.dart';

/// One row in the Library or Focus list: hanzi, pinyin, English, star.
class EntryTile extends StatelessWidget {
  const EntryTile(this.entry, {super.key, this.trailingNote});

  final Entry entry;
  final Widget? trailingNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entry.isSentence) return _sentence(context, theme);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EntryScreen(entry)),
      ),
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryScreen(entry))),
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
