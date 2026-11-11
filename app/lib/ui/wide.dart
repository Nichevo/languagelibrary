import 'package:flutter/material.dart';

import '../models/entry.dart';

/// Screens at least this wide (an iPad in landscape, a tablet, a desktop
/// window) get the side rail and the two-pane Library.
const wideWidth = 900.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideWidth;

/// Keeps a page's content to a comfortable reading width on a big screen,
/// centred, instead of stretching lines and cards across the whole iPad.
/// On a phone it changes nothing.
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 820});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth <= maxWidth || !box.hasBoundedHeight
        ? child
        : Center(
            child: SizedBox(width: maxWidth, height: box.maxHeight, child: child),
          ),
  );
}

/// Present above a list shown beside a word page (the two-pane Library):
/// tapping a word shows it in the other pane instead of opening a new page.
class EntryPicker extends InheritedWidget {
  const EntryPicker({super.key, required this.selected, required this.onPick, required super.child});

  final String? selected;
  final ValueChanged<Entry> onPick;

  static EntryPicker? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EntryPicker>();

  @override
  bool updateShouldNotify(EntryPicker old) => selected != old.selected;
}
