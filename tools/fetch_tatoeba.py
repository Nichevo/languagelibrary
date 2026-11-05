#!/usr/bin/env python3
"""Pick Mandarin-English sentence pairs from the Tatoeba exports.

Keeps a Mandarin sentence only if the person who added it says on their
Tatoeba profile that Mandarin is their native language (skill level 5), it is
short, and it has at least one English translation. Every row keeps both
sentence IDs and both usernames so the app can credit them (CC BY 2.0 FR).

tatoeba.org is not reachable from every build machine, so this normally runs
in GitHub Actions (.github/workflows/fetch-tatoeba.yml) and commits the result.

    python3 -m tools.fetch_tatoeba [--from DIR]   # DIR holds already-downloaded exports
"""

from __future__ import annotations

import argparse
import bz2
import tarfile
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tools" / "sources" / "tatoeba_cmn_eng.tsv"
BASE = "https://downloads.tatoeba.org/exports/"
FILES = {
    "cmn_sentences_detailed.tsv.bz2": BASE + "per_language/cmn/cmn_sentences_detailed.tsv.bz2",
    "eng_sentences_detailed.tsv.bz2": BASE + "per_language/eng/eng_sentences_detailed.tsv.bz2",
    "cmn-eng_links.tsv.bz2": BASE + "per_language/cmn/cmn-eng_links.tsv.bz2",
    "user_languages.tar.bz2": BASE + "user_languages.tar.bz2",
}
MAX_HANZI = 16  # short, everyday sentences only
NATIVE = "5"


def _rows(text: str):
    # Plain split: the exports are unquoted, and some fields contain a stray \r.
    for line in text.split("\n"):
        if line:
            yield line.rstrip("\r").split("\t")


def read_bz2(path: Path) -> str:
    return bz2.decompress(path.read_bytes()).decode("utf-8")


def read_user_languages(path: Path) -> str:
    with tarfile.open(path, "r:bz2") as t:
        member = next(m for m in t.getmembers() if m.isfile())
        return t.extractfile(member).read().decode("utf-8")


def native_speakers(user_languages: str, lang: str) -> set[str]:
    """Usernames that list `lang` at skill level 5 (native)."""
    out = set()
    for r in _rows(user_languages):
        if len(r) >= 3 and r[0] == lang and r[1] == NATIVE and r[2] not in ("", r"\N"):
            out.add(r[2])
    return out


def sentences(detailed: str) -> dict[str, tuple[str, str]]:
    """id -> (text, username); sentences without an owner are skipped."""
    out = {}
    for r in _rows(detailed):
        if len(r) >= 4 and r[3] not in ("", r"\N"):
            out[r[0]] = (r[2].strip(), r[3])
    return out


def hanzi_count(s: str) -> int:
    return sum(1 for c in s if "一" <= c <= "鿿")


def pick(cmn: dict, eng: dict, links: str, native_cmn: set[str], native_eng: set[str]):
    """Rows of (cmn_id, cmn_text, cmn_user, eng_id, eng_text, eng_user, eng_native)."""
    trans = defaultdict(list)
    for r in _rows(links):
        if len(r) >= 2 and r[0] in cmn and r[1] in eng:
            trans[r[0]].append(r[1])
    rows = []
    for cid, (text, user) in cmn.items():
        if user not in native_cmn or not trans[cid]:
            continue
        if not 1 <= hanzi_count(text) <= MAX_HANZI:
            continue
        # Prefer an English translation written by a native English speaker.
        eid = sorted(trans[cid], key=lambda e: (eng[e][1] not in native_eng, int(e)))[0]
        etext, euser = eng[eid]
        rows.append((cid, text, user, eid, etext, euser, "1" if euser in native_eng else "0"))
    rows.sort(key=lambda r: int(r[0]))
    return rows


def download(dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    for name, url in FILES.items():
        print(f"downloading {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "language-library-data-build"})
        with urllib.request.urlopen(req, timeout=300) as r:
            (dest / name).write_bytes(r.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", type=Path, help="folder with the export files already downloaded")
    args = ap.parse_args()
    src = args.src or ROOT / "build" / "tatoeba"
    if not args.src:
        download(src)
    ul = read_user_languages(src / "user_languages.tar.bz2")
    rows = pick(
        sentences(read_bz2(src / "cmn_sentences_detailed.tsv.bz2")),
        sentences(read_bz2(src / "eng_sentences_detailed.tsv.bz2")),
        read_bz2(src / "cmn-eng_links.tsv.bz2"),
        native_speakers(ul, "cmn"),
        native_speakers(ul, "eng"),
    )
    with OUT.open("w", encoding="utf-8", newline="") as f:
        f.write("# Tatoeba (https://tatoeba.org), CC BY 2.0 FR. Made by tools/fetch_tatoeba.py; do not edit.\n")
        f.write("# Mandarin added by a self-declared native speaker; English is one linked translation.\n")
        f.write("cmn_id\tcmn\tcmn_user\teng_id\teng\teng_user\teng_native\n")
        for r in rows:
            f.write("\t".join(x.replace("\t", " ") for x in r) + "\n")
    print(f"wrote {len(rows)} sentence pairs to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
