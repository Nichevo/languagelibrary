"""Small helper for the Windows scripts.

    python -m tools.voices_status            exit 0 if some entries have no clips yet (or clips
                                             are listed in tools/sources/remake_clips.tsv to make again), else 2
    python -m tools.voices_status --voices   print "FEMALE MALE" if voices were picked before
"""

from __future__ import annotations

import json
import sys

from tools.generate_audio import SETS, remakes_due


def _manifest(name: str = "app") -> dict:
    manifest = SETS[name][1] / "manifest.json"
    if not manifest.exists():
        return {"voices": {}, "clips": {}}
    return json.loads(manifest.read_text(encoding="utf-8"))


def missing() -> int:
    """Clips still to make, across every word set that has its word list."""
    n = 0
    for name, (library, _, _) in SETS.items():
        if not library.exists():
            continue
        clips = _manifest(name).get("clips", {})
        entries = json.loads(library.read_text(encoding="utf-8"))["entries"]
        n += sum(1 for e in entries for k in ("f", "m") if f"{e['id']}_{k}" not in clips)
    return n


def remakes() -> int:
    """Clips in the app's word list that someone asked to have made again."""
    library = SETS["app"][0]
    if not library.exists():
        return 0
    entries = json.loads(library.read_text(encoding="utf-8"))["entries"]
    return len(remakes_due(entries, _manifest()))


def main(argv: list[str]) -> int:
    if "--voices" in argv:
        v = _manifest().get("voices", {})
        if v.get("female") and v.get("male"):
            print(v["female"], v["male"])
        return 0
    n = missing()
    print(f"{n} voice clips still to make." if n else "Every word has its voices.")
    r = remakes()
    if r:
        print(f"{r} voice clips to make again (tools/sources/remake_clips.tsv).")
    return 0 if n or r else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
