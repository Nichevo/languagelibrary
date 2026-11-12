#!/usr/bin/env python3
"""Every reading, with its tone, that CC-CEDICT gives each character.

    python3 -m tools.char_tones                  # downloads CC-CEDICT
    python3 -m tools.char_tones --cedict cedict.u8

The app's "Say it" practice uses it to tell what the speech recogniser heard:
if you meant 买 mǎi and it wrote 卖, the table says 卖 is mài, so the app can
say the tone came out as a 4th. Characters the recogniser writes for the same
sound (见 for 件, both jiàn) count as right.

Readings come from single-character CC-CEDICT entries. A character with no
entry of its own takes the readings it has inside longer words. The library's
own words are added last, so the app never disagrees with itself.

Output: app/assets/data/char_tones.tsv (character, tab, readings like "jian4").
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from tools import build_data

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "app" / "assets" / "data" / "char_tones.tsv"
LIBRARY = ROOT / "app" / "assets" / "data" / "library.json"

_SYL = re.compile(r"^[a-zü]+[1-5]$")


def _syllables(numbered: str) -> list[str]:
    return numbered.lower().replace("u:", "ü").replace("v", "ü").split()


def char_tones(cedict: list[dict], library_entries: list[dict] = ()) -> dict[str, set[str]]:
    own: dict[str, set[str]] = {}
    in_words: dict[str, set[str]] = {}
    for c in cedict:
        word = c["simplified"]
        syls = _syllables(c["pinyin"])
        if len(syls) != len(word):
            continue
        for ch, s in zip(word, syls):
            if not _SYL.match(s) or not "一" <= ch <= "鿿":
                continue
            if len(word) == 1:
                own.setdefault(ch, set()).add(s)
            elif not s.endswith("5"):
                in_words.setdefault(ch, set()).add(s)
    table = dict(own)
    for ch, readings in in_words.items():
        table.setdefault(ch, readings)
    for e in library_entries:
        syls = _syllables(e["pinyinNumbered"])
        if len(syls) == len(e["simplified"]):
            for ch, s in zip(e["simplified"], syls):
                if _SYL.match(s) and "一" <= ch <= "鿿":
                    table.setdefault(ch, set()).add(s)
    return table


def write(table: dict[str, set[str]], out: Path = OUT) -> None:
    lines = [
        "# Readings with tones for each character, from CC-CEDICT (CC BY-SA 4.0, see CREDITS).",
        "# Made by tools/char_tones.py; used by the Say it practice.",
    ] + [f"{ch}\t{' '.join(sorted(table[ch]))}" for ch in sorted(table)]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cedict", help="local CC-CEDICT file (default: download from MDBG)")
    args = ap.parse_args()
    cedict = build_data.load_cedict(args.cedict)
    entries = json.loads(LIBRARY.read_text(encoding="utf-8"))["entries"] if LIBRARY.exists() else []
    table = char_tones(cedict, entries)
    write(table)
    print(f"{len(table)} characters -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
