"""Small helper for the Windows scripts.

    python -m tools.voices_status            exit 0 if some entries have no clips yet, else 2
    python -m tools.voices_status --voices   print "FEMALE MALE" if voices were picked before
"""

from __future__ import annotations

import json
import sys

from tools.generate_audio import LIBRARY, MANIFEST


def _manifest() -> dict:
    if not MANIFEST.exists():
        return {"voices": {}, "clips": {}}
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def missing() -> int:
    clips = _manifest().get("clips", {})
    entries = json.loads(LIBRARY.read_text(encoding="utf-8"))["entries"]
    return sum(1 for e in entries for k in ("f", "m") if f"{e['id']}_{k}" not in clips)


def main(argv: list[str]) -> int:
    if "--voices" in argv:
        v = _manifest().get("voices", {})
        if v.get("female") and v.get("male"):
            print(v["female"], v["male"])
        return 0
    n = missing()
    print(f"{n} voice clips still to make." if n else "Every word has its voices.")
    return 0 if n else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
