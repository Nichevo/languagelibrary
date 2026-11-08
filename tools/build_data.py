#!/usr/bin/env python3
"""Build the app's word library from open sources.

    python3 -m tools.build_data                     # downloads the sources
    python3 -m tools.build_data --cedict cedict.u8 --hsk complete.json

Sources (see CREDITS.md):
  * complete-hsk-vocabulary (MIT): which words, HSK level, frequency
  * CC-CEDICT (CC BY-SA 4.0): pinyin, meanings, measure words, traditional form

Safety rules, because nobody is checking the output by ear:
  * A word is kept only if CC-CEDICT has an entry with the same simplified
    hanzi AND the same pinyin as the HSK list. Otherwise it is dropped and
    listed in the build report.
  * Every syllable must be a real Mandarin syllable.
  * Meanings shown in the app come only from CC-CEDICT.
  * Characters with more than one reading are flagged for the audio check.

Outputs:
  app/assets/data/library.json   the data the app loads
  tools/build_report.md          what was dropped or flagged, and why
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import re
import sys
import urllib.request
import zipfile
from collections import defaultdict
from datetime import date
from pathlib import Path

from tools import pinyin as py
from tools import sentences

ROOT = Path(__file__).resolve().parent.parent
SOURCES = Path(__file__).resolve().parent / "sources"
OUT_JSON = ROOT / "app" / "assets" / "data" / "library.json"
OUT_REPORT = Path(__file__).resolve().parent / "build_report.md"

HSK_URL = "https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/complete.json"
CEDICT_URL = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"

# HSK 3.0 levels 1 to 6 plus the curated phrases. Change with --levels.
# The app shows levels 1 to 3 at first; the rest are switched on in Settings.
DEFAULT_LEVELS = ["new-1", "new-2", "new-3", "new-4", "new-5", "new-6"]

_CEDICT_LINE = re.compile(r"^(\S+) (\S+) \[([^\]]+)\] /(.*)/\s*$")
_ERHUA = re.compile(r"^erhua variant of (?:[^|\[]+\|)?([^\[]+)\[([^\]]+)\]")
_CL = re.compile(r"^CL:(.*)$")
_CL_ITEM = re.compile(r"(?:[^|\[,]+\|)?([^\[,]+)\[([^\]]+)\]")


# ---------------------------------------------------------------- loading

def _download(url: str) -> bytes:
    print(f"downloading {url}", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def load_cedict(path: str | None) -> list[dict]:
    if path:
        text = Path(path).read_text(encoding="utf-8")
    else:
        raw = _download(CEDICT_URL)
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            text = z.read(z.namelist()[0]).decode("utf-8")
    return parse_cedict(text.splitlines())


def parse_cedict(lines) -> list[dict]:
    entries = []
    for line in lines:
        if not line or line.startswith("#"):
            continue
        m = _CEDICT_LINE.match(line)
        if not m:
            continue
        trad, simp, pin, body = m.groups()
        glosses, classifiers = [], []
        for g in body.split("/"):
            cl = _CL.match(g)
            if cl:
                for hz, p in _CL_ITEM.findall(cl.group(1)):
                    classifiers.append({"hanzi": hz, "pinyin": p})
            elif g:
                glosses.append(g)
        entries.append({
            "traditional": trad,
            "simplified": simp,
            "pinyin": pin,
            "glosses": glosses,
            "classifiers": classifiers,
        })
    return entries


def load_hsk(path: str | None) -> list[dict]:
    raw = Path(path).read_bytes() if path else _download(HSK_URL)
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw)


def load_phrases() -> list[tuple[str, str, str]]:
    out = []
    for line in (SOURCES / "phrases.tsv").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            hz, pin, topic = line.split("\t")
            out.append((hz, pin, topic))
    return out


def load_readings() -> dict[str, list[str]]:
    out = {}
    for line in (SOURCES / "readings.tsv").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            hz, readings = line.split("\t")
            out[hz] = [r.strip() for r in readings.split(",")]
    return out


def load_topic_rules() -> dict[str, dict[str, set[str]]]:
    rules: dict[str, dict[str, set[str]]] = defaultdict(lambda: {"keywords": set(), "hanzi": set()})
    for line in (SOURCES / "topics.tsv").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            topic, kind, values = line.split("\t")
            rules[topic][kind] |= {v.strip().lower() for v in values.split(",") if v.strip()}
    return rules


# ---------------------------------------------------------------- helpers

def same_pinyin(a: str, b: str) -> bool:
    """Compare numbered pinyin ignoring case and spacing quirks."""
    norm = lambda s: py.normalise_letters(s).replace(" ", "")
    return norm(a) == norm(b)


_NOISE = re.compile(
    r"^(variant of|old variant of|erhua variant of|euphemistic variant|see |used in |surname |abbr\. |\(archaic\)|archaic)",
    re.I,
)


def useful_glosses(glosses: list[str]) -> list[str]:
    return [g for g in glosses if not _NOISE.match(g)]


def topics_for(hanzi: str, meanings: list[str], rules) -> list[str]:
    text = " ".join(meanings).lower()
    words = set(re.findall(r"[a-z']+", text))
    found = []
    for topic, r in rules.items():
        if hanzi in r["hanzi"]:
            found.append(topic)
            continue
        for kw in r["keywords"]:
            if (" " in kw and kw in text) or kw in words:
                found.append(topic)
                break
    return sorted(set(found))


def entry_id(simplified: str, numbered: str) -> str:
    return hashlib.sha1(f"{simplified}|{numbered}".encode()).hexdigest()[:10]


def polyphonic_chars(cedict: list[dict]) -> set[str]:
    """Characters CC-CEDICT gives more than one reading for (e.g. 行 xíng / háng)."""
    readings: dict[str, set[str]] = defaultdict(set)
    for e in cedict:
        s = e["simplified"]
        if len(s) == 1 and e["pinyin"][:1].islower() and useful_glosses(e["glosses"]):
            p = py.normalise_letters(e["pinyin"])
            if not p.endswith("5"):  # a light-tone version of the same reading is not a new reading
                readings[s].add(p)
    return {ch for ch, r in readings.items() if len(r) > 1}


# ---------------------------------------------------------------- build

def build(cedict: list[dict], hsk: list[dict], phrases, levels: list[str]):
    by_simp: dict[str, list[dict]] = defaultdict(list)
    for e in cedict:
        by_simp[e["simplified"]].append(e)
    poly = polyphonic_chars(cedict)
    rules = load_topic_rules()

    dropped: list[tuple[str, str]] = []
    flagged: list[tuple[str, str]] = []
    entries: dict[str, dict] = {}

    def make(simp: str, numbered: str, source: str, hsk_level, freq, extra_topic=None):
        try:
            syls = py.parse_numbered(numbered)
        except ValueError as err:
            dropped.append((simp, f"pinyin could not be read ({err})"))
            return
        bad = [s.numbered for s in syls if not py.is_valid(s)]
        if bad:
            dropped.append((simp, f"not real Mandarin syllables: {', '.join(bad)}"))
            return
        if len(syls) != len([c for c in simp if not c.isascii()]):
            dropped.append((simp, f"{len(syls)} syllables for {len(simp)} characters"))
            return
        matches = [e for e in by_simp.get(simp, []) if same_pinyin(e["pinyin"], numbered)]
        if not matches:
            have = ", ".join(sorted({e["pinyin"] for e in by_simp.get(simp, [])})) or "no entry"
            dropped.append((simp, f"CC-CEDICT does not agree: list says [{numbered}], CC-CEDICT has [{have}]"))
            return
        meanings, classifiers, trad = [], [], matches[0]["traditional"]
        for m in matches:
            for g in useful_glosses(m["glosses"]):
                if g not in meanings:
                    meanings.append(g)
            for c in m["classifiers"]:
                if c not in classifiers:
                    classifiers.append(c)
        notes = []
        if not meanings:
            # e.g. 一点儿 is listed as "erhua variant of 一點|一点[yi1 dian3]":
            # borrow the meanings of the base word, still from CC-CEDICT.
            base = next((m for g in (x for e in matches for x in e["glosses"]) if (m := _ERHUA.match(g))), None)
            if base:
                b_simp, b_pin = base.group(1), base.group(2)
                for e in by_simp.get(b_simp, []):
                    if same_pinyin(e["pinyin"], b_pin):
                        meanings += [g for g in useful_glosses(e["glosses"]) if g not in meanings]
                if meanings:
                    notes.append(f"Northern spoken form of {b_simp} ({py.to_marks(b_pin)}) with an -r ending")
        if not meanings:
            dropped.append((simp, "CC-CEDICT only lists it as a variant or cross-reference"))
            return
        eid = entry_id(simp, numbered)
        if eid in entries:
            if source not in entries[eid]["sources"]:
                entries[eid]["sources"].append(source)
            if extra_topic and extra_topic not in entries[eid]["topics"]:
                entries[eid]["topics"] = sorted(entries[eid]["topics"] + [extra_topic])
            return
        marked = py.join_marked([s.marked for s in syls])
        poly_here = sorted({c for c in simp if c in poly})
        if poly_here:
            flagged.append((simp, f"has characters with more than one reading ({''.join(poly_here)}); listen to its audio"))
        topics = topics_for(simp, meanings, rules)
        if extra_topic and extra_topic not in topics:
            topics.append(extra_topic)
        entries[eid] = {
            "id": eid,
            "simplified": simp,
            "traditional": trad,
            "pinyin": marked,
            "pinyinNumbered": " ".join(s.numbered for s in syls),
            "meanings": meanings,
            "classifiers": [
                {"hanzi": c["hanzi"], "pinyin": py.to_marks(c["pinyin"])} for c in classifiers
            ],
            "hsk": hsk_level,
            "frequency": freq,
            "topics": sorted(topics) or ["everyday"],
            "pronunciation": py.breakdown(simp, numbered),
            "polyphonic": bool(poly_here),
            "notes": notes,
            "sources": [source, "CC-CEDICT"],
        }

    wanted = set(levels)
    chosen = load_readings()
    for w in hsk:
        lv = [l for l in w["level"] if l in wanted]
        if not lv:
            continue
        level_num = min(int(l.split("-")[1]) for l in lv)
        simp = w["simplified"]
        candidates = sorted({
            f["transcriptions"]["numeric"]
            for f in w["forms"]
            if f["transcriptions"]["numeric"][:1].islower() and useful_glosses(f["meanings"])
        })
        if len(candidates) > 1:
            if simp not in chosen:
                dropped.append((simp, f"several readings ({', '.join(candidates)}) and none chosen in readings.tsv"))
                continue
            picks = chosen[simp]
            missing = [p for p in picks if not any(same_pinyin(p, c) for c in candidates)]
            if missing:
                dropped.append((simp, f"readings.tsv picks {', '.join(missing)}, which the sources do not list"))
                continue
            candidates = picks
        for numbered in candidates:
            # A few list entries leave the light tone unnumbered ("zhen1 de"); CC-CEDICT must still agree.
            numbered = " ".join(t if t[-1:].isdigit() else t + "5" for t in numbered.split())
            make(simp, numbered, "HSK", level_num, w.get("frequency"))

    for hz, pin, topic in phrases:
        make(hz, pin, "Curated phrase list", None, None, extra_topic=topic)

    ordered = sorted(entries.values(), key=lambda e: (e["hsk"] or 99, e["frequency"] or 10**9, e["simplified"]))
    add_related(ordered)
    return ordered, dropped, flagged


# Very common characters that link too many unrelated words to be useful on their own.
_COMMON_CHARS = set("一不了的是有人大子儿么个们这那在我你他她它")
_PAREN = re.compile(r"\([^)]*\)")
MAX_RELATED = 10


def _meaning_keys(e: dict) -> set[str]:
    """The main senses (first two glosses), lower-cased without bracketed notes.

    Only main senses are compared, so rare senses (用 "(honorific) to eat")
    don't link unrelated everyday words."""
    keys = set()
    for g in e["meanings"][:2]:
        for part in g.split(";"):
            k = _PAREN.sub("", part).strip().lower()
            if len(k) >= 3:
                keys.add(k)
    return keys


def load_opposites() -> list[tuple[str, str, str, str]]:
    """(hanzi, English, opposite hanzi, its English) from tools/sources/opposites.tsv."""
    path = SOURCES / "opposites.tsv"
    out = []
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                a, x, b, y = line.split("\t")[:4]
                out.append((a, x, b, y))
    return out


def _main_senses(e: dict) -> set[str]:
    """Short glosses from the first three meanings ("to open" -> "open"), the ones
    opposites.tsv was matched against."""
    out = set()
    for m in e["meanings"][:3]:
        for g in m.split(";")[:3]:
            g = re.sub(r"^to ", "", _PAREN.sub("", g).strip().lower())
            if g and len(g.split()) <= 2:
                out.add(g)
    return out


def add_related(entries: list[dict], opposites=None) -> None:
    """Link entries to others in the library, using only facts from the data:
    opposites (WordNet antonyms of the main meanings), same characters with
    another reading, the measure word, shared meanings, and shared characters.
    Each link says why, in plain English."""
    by_simp: dict[str, list[dict]] = defaultdict(list)
    by_meaning: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        by_simp[e["simplified"]].append(e)
        for k in _meaning_keys(e):
            by_meaning[k].append(e)

    # Opposites both ways, matched on the reading whose main meaning is the listed one.
    opposite_of: dict[str, list[tuple[dict, str]]] = defaultdict(list)
    for a, x, b, y in (load_opposites() if opposites is None else opposites):
        ea = [o for o in by_simp.get(a, []) if o.get("kind", "word") == "word" and x in _main_senses(o)]
        eb = [o for o in by_simp.get(b, []) if o.get("kind", "word") == "word" and y in _main_senses(o)]
        for p in ea:
            for q in eb:
                opposite_of[p["id"]].append((q, f"Opposite: {x} / {y}"))
                opposite_of[q["id"]].append((p, f"Opposite: {y} / {x}"))

    for e in entries:
        links: list[dict] = []
        seen = {e["id"]}

        def add(other: dict, why: str) -> None:
            if other["id"] not in seen and len(links) < MAX_RELATED:
                seen.add(other["id"])
                links.append({"id": other["id"], "why": why})

        for o, why in opposite_of.get(e["id"], []):
            add(o, why)
        simp = e["simplified"]
        for o in by_simp[simp]:
            add(o, "Same characters, different reading")
        for c in e["classifiers"]:
            for o in by_simp.get(c["hanzi"], []):
                if o["pinyin"] == c["pinyin"]:
                    add(o, "Its measure word")
        for k in sorted(_meaning_keys(e)):
            for o in by_meaning[k]:
                add(o, f"Also means \"{k}\"")
        # longer words and phrases that contain this one
        containing = [o for o in entries if o["simplified"] != simp and simp in o["simplified"]]
        for o in containing[:4]:
            add(o, f"Contains {simp}")
        # the parts this word is made of
        if len(simp) > 1:
            for ch in simp:
                for o in by_simp.get(ch, []):
                    add(o, f"Part of {simp}")
        # other words sharing a less common character
        for ch in simp:
            if ch in _COMMON_CHARS or len(simp) == 1:
                continue
            for o in entries:
                if ch in o["simplified"] and o["simplified"] != simp and len(o["simplified"]) > 1:
                    add(o, f"Also uses {ch}")
        e["related"] = links


def write_outputs(entries, dropped, flagged, levels, cedict_note: str, sentence_note: str = "",
                  out_json: Path | None = None, out_report: Path | None = None):
    out_json = out_json or OUT_JSON
    out_report = out_report or OUT_REPORT
    out_json.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "version": 1,
        "built": date.today().isoformat(),
        "levels": levels,
        "sources": {"cedict": cedict_note, **({"tatoeba": "tools/sources/tatoeba_cmn_eng.tsv"} if sentence_note else {})},
        "entries": entries,
    }
    out_json.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    lines = [
        "# Build report",
        "",
        f"Built {date.today().isoformat()} from HSK levels {', '.join(levels)} plus the curated phrase list.",
        f"Kept **{len(entries)}** entries, dropped **{len(dropped)}**, flagged **{len(flagged)}**.",
        *([sentence_note, "Sentences come from Tatoeba (native Mandarin speakers only); see tools/sentences.py."] if sentence_note else []),
        "",
        "## Dropped (not shown in the app)",
        "",
    ]
    lines += [f"- {hz}: {why}" for hz, why in dropped] or ["- none"]
    lines += ["", "## Flagged (kept, but check the audio by ear)", ""]
    lines += [f"- {hz}: {why}" for hz, why in flagged] or ["- none"]
    out_report.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cedict", help="local CC-CEDICT file (default: download from MDBG)")
    ap.add_argument("--hsk", help="local complete.json (default: download)")
    ap.add_argument("--levels", nargs="+", default=DEFAULT_LEVELS,
                    help="HSK levels to include, e.g. new-1 new-2 (default: new-1 to new-6)")
    ap.add_argument("--out", type=Path, help="where to write library.json (default: the app's own)")
    ap.add_argument("--words-only", action="store_true",
                    help="only the HSK words: no curated phrases or phrasebook sentences")
    args = ap.parse_args(argv)
    out_json = args.out.resolve() if args.out else OUT_JSON
    out_report = out_json.parent / "build_report.md" if args.out else OUT_REPORT

    cedict = load_cedict(args.cedict)
    note = Path(args.cedict).name if args.cedict else CEDICT_URL
    hsk = load_hsk(args.hsk)
    entries, dropped, flagged = build(cedict, hsk, [] if args.words_only else load_phrases(), args.levels)
    pairs = sentences.load_pairs()
    sentence_note = ""
    if pairs:
        reader = sentences.Reader(cedict, entries, hsk)
        with_examples = sentences.add_examples(reader, pairs, entries)
        picks = [] if args.words_only else sentences.load_phrasebook()
        book, book_dropped = sentences.phrasebook_entries(reader, pairs, picks, entries)
        entries += book
        dropped += book_dropped
        sentence_note = f"{len(book)} phrasebook sentences; {with_examples} words have example sentences."
    write_outputs(entries, dropped, flagged, args.levels, note, sentence_note, out_json, out_report)
    print(f"kept {len(entries)}, dropped {len(dropped)}, flagged {len(flagged)} -> {out_json.relative_to(ROOT)}")
    if sentence_note:
        print(sentence_note)


if __name__ == "__main__":
    main()
