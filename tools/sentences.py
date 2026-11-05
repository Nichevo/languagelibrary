"""Turn Tatoeba sentence pairs into example sentences and phrasebook entries.

Nothing here is made up: the Chinese and English come from Tatoeba (native
Mandarin speakers only, see fetch_tatoeba.py) and the pinyin is looked up word
by word, from the library's own checked entries first and CC-CEDICT second.
A sentence is used only when every word has exactly one reading. If any word
could be read two ways (还 hái / huán), or a character is not a simplified
one, the sentence is left out rather than guessed.
"""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

from tools import pinyin as py

SOURCES = Path(__file__).resolve().parent / "sources"
TATOEBA = SOURCES / "tatoeba_cmn_eng.tsv"
PHRASEBOOK = SOURCES / "sentences.tsv"

MAX_WORD = 8
MAX_EXAMPLE_HANZI = 12
EXAMPLES_PER_ENTRY = 3
PUNCT = {"。": ".", "？": "?", "！": "!", "，": ",", "、": ",", "：": ":", "；": ";",
         "?": "?", "!": "!", ",": ",", ".": ".", "…": "…", "“": '"', "”": '"', " ": ""}
SENTENCE_NOTE = ("Pinyin shows each word's own tones. In quick speech some tones also change "
                 "between words, for example two 3rd tones in a row.")


def is_hanzi(c: str) -> bool:
    return "一" <= c <= "鿿" or c == "〇"


def load_pairs(path: Path = TATOEBA) -> list[dict]:
    if not path.exists():
        return []
    rows = []
    lines = [l for l in path.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")]
    head = lines[0].split("\t")
    for line in lines[1:]:
        r = dict(zip(head, line.split("\t")))
        if len(r) == len(head):
            rows.append(r)
    return rows


def load_phrasebook(path: Path = PHRASEBOOK) -> list[tuple[str, str]]:
    """(tatoeba id, topic) pairs picked by hand from the Tatoeba list."""
    out = []
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                sid, topic = line.split("\t")[:2]
                out.append((sid.strip(), topic.strip()))
    return out


class Reader:
    """Splits a sentence into words and finds each word's one reading.

    Only two word lists are used, both already cross-checked: the library's own
    entries (where readings.tsv picked the everyday reading of words like 要 or
    了) and the full HSK list (levels 1 to 9), each HSK reading confirmed by
    CC-CEDICT. Odd dictionary entries such as 说中 or 过得 are not words here,
    so they can't swallow the characters next to them.

    A run of characters is split into the fewest words. If two different
    splits would be read differently, the sentence is left out.
    """

    def __init__(self, cedict: list[dict], library: list[dict], hsk: list[dict] = ()):
        trad_chars, simp_chars = set(), set()
        cedict_readings: dict[str, set[str]] = defaultdict(set)
        for e in cedict:
            simp_chars.update(e["simplified"])
            trad_chars.update(e["traditional"])
            cedict_readings[e["simplified"]].add(_norm(e["pinyin"]))
        self.traditional_only = trad_chars - simp_chars
        self.simplified = simp_chars

        self.words: dict[str, set[str]] = {}
        for w in hsk:
            forms = [f["transcriptions"]["numeric"] for f in w["forms"]]
            lower = [f for f in forms if f[:1].islower()]
            agreed = {_norm(f) for f in (lower or forms) if _norm(f) in cedict_readings.get(w["simplified"], ())}
            if agreed:
                self.words.setdefault(w["simplified"], set()).update(agreed)
        self.entry_for: dict[str, list[dict]] = defaultdict(list)
        for e in library:
            if e.get("kind", "word") == "word":
                self.entry_for[e["simplified"]].append(e)
        for w, es in self.entry_for.items():
            self.words[w] = {_norm(e["pinyinNumbered"]) for e in es}
        self.longest = max(map(len, self.words), default=1)

    def _split_run(self, run: str):
        """Fewest-words split of a run of hanzi: (tokens, '') or (None, why)."""
        n = len(run)
        # best[i] = (word count, [token lists]) for run[:i]; keep at most two splits.
        best: list = [None] * (n + 1)
        best[0] = (0, [[]])
        for i in range(n):
            if best[i] is None:
                continue
            count, splits = best[i]
            for j in range(i + 1, min(n, i + self.longest) + 1):
                w = run[i:j]
                if w not in self.words:
                    continue
                cand = (count + 1, [s + [w] for s in splits])
                if best[j] is None or cand[0] < best[j][0]:
                    best[j] = (cand[0], cand[1][:2])
                elif cand[0] == best[j][0]:
                    best[j] = (cand[0], (best[j][1] + cand[1])[:2])
        if best[n] is None:
            missing = next((c for c in run if c not in self.words), run)
            return None, f"{missing} is not a word in the checked lists"
        readings = set()
        for split in best[n][1]:
            toks = []
            for w in split:
                opts = self.words[w]
                if len(opts) != 1:
                    return None, f"{w} has more than one reading ({', '.join(sorted(opts))})"
                toks.append((w, next(iter(opts))))
            readings.add(tuple(toks))
        if len({tuple(n for _, n in t) for t in readings}) > 1:
            return None, "it can be split into words in two ways that read differently"
        return list(next(iter(readings))), ""

    def read(self, text: str) -> tuple[list[tuple[str, str | None]] | None, str]:
        """[(token, numbered or None for punctuation)], or (None, why it was left out)."""
        text = text.strip()
        bad = [c for c in text if not is_hanzi(c) and c not in PUNCT]
        if bad:
            return None, f"has letters or digits ({''.join(bad)})"
        if any(c in self.traditional_only or (is_hanzi(c) and c not in self.simplified) for c in text):
            return None, "written in traditional characters"
        tokens, run = [], ""
        for c in text + "\0":
            if is_hanzi(c):
                run += c
                continue
            if run:
                toks, why = self._split_run(run)
                if toks is None:
                    return None, why
                tokens += toks
                run = ""
            if c != "\0":
                tokens.append((c, None))
        return tokens, ""


def _norm(numbered: str) -> str:
    return " ".join(py.normalise_letters(t) for t in numbered.split()).lower()


def _spoken_tones(tokens) -> tuple[list[int], list[str]]:
    """Tones as said. 3rd-tone changes are applied inside each word only; the
    不 and 一 changes, which follow the next syllable whatever word it is in,
    across the whole sentence."""
    words = [(w, py.parse_numbered(n)) for w, n in tokens if n is not None]
    hanzi = "".join(w for w, _ in words)
    syls = [s for _, ss in words for s in ss]
    whole = py.apply_sandhi(hanzi, syls) if len(hanzi) == len(syls) else None
    tones, notes, i = [], [], 0
    for w, ss in words:
        inner = py.apply_sandhi(w, ss)
        for k, s in enumerate(ss):
            t = inner.spoken[k]
            if whole and w[k] in "一不":
                t = whole.spoken[i]
            tones.append(t)
            i += 1
        notes += [x for x in inner.notes if x.startswith(("Two", "Several")) and x not in notes]
    if whole:
        notes += [x for x in whole.notes if x.startswith(("一", "不")) and x not in notes]
    return tones, notes


def _pinyin_text(tokens, tones: list[int] | None = None) -> tuple[str, str]:
    """(marked pinyin with punctuation, numbered pinyin). With `tones`, marks those instead."""
    marked, numbered, i = [], [], 0
    for w, n in tokens:
        if n is None:
            p = PUNCT.get(w, w)
            if marked and p:
                marked[-1] += p
            continue
        syls = py.parse_numbered(n)
        if tones is not None:
            syls = [py.Syllable(s.letters, tones[i + k], s.capital) for k, s in enumerate(syls)]
        i += len(syls)
        marked.append(py.join_marked([s.marked for s in syls]))
        numbered.append(n)
    text = " ".join(marked)
    text = re.sub(r"(^|[.?!] )(\w)", lambda m: m.group(1) + m.group(2).upper(), text)
    return text, " ".join(numbered)


def _pronunciation(tokens) -> dict:
    tones, notes = _spoken_tones(tokens)
    syllables, i = [], 0
    for w, n in tokens:
        if n is None:
            continue
        for part in py.breakdown(w, n)["syllables"]:
            part["spokenTone"] = tones[i]
            syllables.append(part)
            i += 1
    spoken = _pinyin_text(tokens, tones)[0] if notes else None
    return {"syllables": syllables, "spoken": spoken, "notes": notes}


def credit(pair: dict) -> list[str]:
    return [f"Tatoeba #{pair['cmn_id']} by {pair['cmn_user']}",
            f"English: Tatoeba #{pair['eng_id']} by {pair['eng_user']}"]


def phrasebook_entries(reader: Reader, pairs: list[dict], picks, library: list[dict]):
    """Hand-picked sentences become full entries (star, lists, flashcards)."""
    by_id = {p["cmn_id"]: p for p in pairs}
    out, dropped = [], []
    seen = set()
    for sid, topic in picks:
        p = by_id.get(sid)
        if p is None:
            dropped.append((f"Tatoeba #{sid}", "not in the native-speaker sentence list"))
            continue
        if sid in seen:
            continue
        seen.add(sid)
        tokens, why = reader.read(p["cmn"])
        if tokens is None:
            dropped.append((p["cmn"], why))
            continue
        marked, numbered = _pinyin_text(tokens)
        words = []
        for w, n in tokens:
            for e in reader.entry_for.get(w, []):
                if n is not None and _norm(e["pinyinNumbered"]) == n and e["id"] not in [x["id"] for x in words]:
                    words.append({"id": e["id"], "why": "Word in this sentence"})
        out.append({
            "id": f"t{sid}",
            "kind": "sentence",
            "simplified": p["cmn"],
            "traditional": "",
            "pinyin": marked,
            "pinyinNumbered": numbered,
            "meanings": [p["eng"]],
            "classifiers": [],
            "hsk": None,
            "frequency": None,
            "topics": [topic],
            "pronunciation": _pronunciation(tokens),
            "polyphonic": False,
            "notes": [SENTENCE_NOTE],
            "sources": credit(p),
            "related": words,
        })
    return out, dropped


# Example sentences skip anything crude or odd for a learner's first look.
_SKIP_ENGLISH = re.compile(
    r"\b(stupid|idiot|kill\w*|die|died|dead|damn|hell|shit\w*|crap|fuck\w*|sex\w*|gun|shoot|dump|"
    r"drunk|suicide|murder\w*|bitch|ass|wilco)\b", re.I)


def add_examples(reader: Reader, pairs: list[dict], library: list[dict]) -> int:
    """Give each word up to three short example sentences that contain it as a word."""
    known_ids = {e["id"] for e in library}
    by_word: dict[str, list[tuple]] = defaultdict(list)
    for p in pairs:
        n_hanzi = sum(map(is_hanzi, p["cmn"]))
        if not 3 <= n_hanzi <= MAX_EXAMPLE_HANZI or _SKIP_ENGLISH.search(p["eng"]) or len(p["eng"].split()) < 2:
            continue
        tokens, _ = reader.read(p["cmn"])
        if tokens is None:
            continue
        words = [(w, n) for w, n in tokens if n is not None]
        if len(words) < 2:
            continue
        in_library = sum(1 for w, n in words if any(_norm(e["pinyinNumbered"]) == n for e in reader.entry_for.get(w, [])))
        # Easier sentences first: most words already in the library, a comfortable
        # length (4 to 10 characters), then English by a native English speaker.
        rank = (-(in_library * 4 // len(words)), not 4 <= n_hanzi <= 10, p["eng_native"] != "1", n_hanzi, int(p["cmn_id"]))
        marked, _ = _pinyin_text(tokens)
        item = {"zh": p["cmn"], "pinyin": marked, "en": p["eng"], "credit": credit(p)}
        for w, n in set(words):
            for e in reader.entry_for.get(w, []):
                if _norm(e["pinyinNumbered"]) == n and e["id"] in known_ids:
                    by_word[e["id"]].append((rank, item))
    count = 0
    for e in library:
        found = sorted(by_word.get(e["id"], []), key=lambda x: x[0])
        picked, texts = [], set()
        for _, item in found:
            key = item["zh"].rstrip("。？！!?.")
            if key not in texts:
                picked.append(item)
                texts.add(key)
            if len(picked) == EXAMPLES_PER_ENTRY:
                break
        e["examples"] = picked
        count += bool(picked)
    return count
