"""Pinyin helpers: tone marks, syllable checks, breakdown and tone sandhi.

Everything here is rule-based and covered by tests in tests/test_pinyin.py,
so pronunciation notes shown in the app never come from guesswork.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

TONE_MARKS = {
    "a": "āáǎà",
    "e": "ēéěè",
    "i": "īíǐì",
    "o": "ōóǒò",
    "u": "ūúǔù",
    "ü": "ǖǘǚǜ",
}

TONE_NAMES = {
    1: "1st tone: high and level",
    2: "2nd tone: rising",
    3: "3rd tone: low dip",
    4: "4th tone: sharp fall",
    5: "neutral tone: light and short",
}

INITIALS = [
    "zh", "ch", "sh",
    "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h",
    "j", "q", "x", "r", "z", "c", "s", "y", "w",
]

_FINALS_BY_INITIAL = {
    "": "a ai an ang ao e ei en eng er o ou m n ng hm",
    "b": "a ai an ang ao ei en eng i ian iao ie in ing o u",
    "p": "a ai an ang ao ei en eng i ian iao ie in ing o ou u",
    "m": "a ai an ang ao e ei en eng i ian iao ie in ing iu o ou u",
    "f": "a an ang ei en eng o ou u",
    "d": "a ai an ang ao e ei en eng i ia ian iao ie ing iu ong ou u uan ui un uo",
    "t": "a ai an ang ao e ei eng i ian iao ie ing ong ou u uan ui un uo",
    "n": "a ai an ang ao e ei en eng i ian iang iao ie in ing iu ong ou u uan uo ü üe",
    "l": "a ai an ang ao e ei eng i ia ian iang iao ie in ing iu o ong ou u uan un uo ü üe",
    "g": "a ai an ang ao e ei en eng ong ou u ua uai uan uang ui un uo",
    "k": "a ai an ang ao e ei en eng ong ou u ua uai uan uang ui un uo",
    "h": "a ai an ang ao e ei en eng m ng ong ou u ua uai uan uang ui un uo",
    "j": "i ia ian iang iao ie in ing iong iu u uan ue un",
    "q": "i ia ian iang iao ie in ing iong iu u uan ue un",
    "x": "i ia ian iang iao ie in ing iong iu u uan ue un",
    "zh": "a ai an ang ao e ei en eng i ong ou u ua uai uan uang ui un uo",
    "ch": "a ai an ang ao e en eng i ong ou u ua uai uan uang ui un uo",
    "sh": "a ai an ang ao e ei en eng i ou u ua uai uan uang ui un uo",
    "r": "an ang ao e en eng i ong ou u ua uan ui un uo",
    "z": "a ai an ang ao e ei en eng i ong ou u uan ui un uo",
    "c": "a ai an ang ao e en eng i ong ou u uan ui un uo",
    "s": "a ai an ang ao e en eng i ong ou u uan ui un uo",
    "y": "a an ang ao e i in ing o ong ou u uan ue un",
    "w": "a ai an ang ei en eng o u",
}

VALID_SYLLABLES = {
    ini + fin
    for ini, fins in _FINALS_BY_INITIAL.items()
    for fin in fins.split()
} | {"r"}  # "r" is the erhua suffix, e.g. 一点儿 yi1 dian3 r5

_SYL_RE = re.compile(r"^([a-zü]+?)([1-5])$")


@dataclass(frozen=True)
class Syllable:
    """One numbered pinyin syllable, e.g. Syllable('hao', 3)."""

    letters: str  # lower case, ü written as ü
    tone: int
    capital: bool = False

    @property
    def numbered(self) -> str:
        return f"{self.letters}{self.tone}"

    @property
    def marked(self) -> str:
        text = add_tone_mark(self.letters, self.tone)
        return text[:1].upper() + text[1:] if self.capital else text


def normalise_letters(text: str) -> str:
    """Lower-case and write ü consistently (CEDICT uses u:, some lists use v)."""
    return text.lower().replace("u:", "ü").replace("v", "ü")


def parse_numbered(pinyin: str) -> list[Syllable]:
    """Parse 'ni3 hao3' into syllables. Raises ValueError on anything odd."""
    out = []
    for raw in pinyin.split():
        norm = normalise_letters(raw)
        m = _SYL_RE.match(norm)
        if not m:
            raise ValueError(f"not a numbered pinyin syllable: {raw!r}")
        out.append(Syllable(m.group(1), int(m.group(2)), raw[:1].isupper()))
    return out


def add_tone_mark(letters: str, tone: int) -> str:
    """Put the tone mark on the right vowel (standard placement rules)."""
    if tone == 5 or tone not in (1, 2, 3, 4):
        return letters
    if "a" in letters:
        target = letters.index("a")
    elif "e" in letters:
        target = letters.index("e")
    elif "ou" in letters:
        target = letters.index("o")
    else:
        vowels = [i for i, ch in enumerate(letters) if ch in TONE_MARKS]
        if not vowels:  # syllabic m / n / ng: leave unmarked
            return letters
        target = vowels[-1]
    ch = letters[target]
    return letters[:target] + TONE_MARKS[ch][tone - 1] + letters[target + 1:]


def join_marked(parts: list[str]) -> str:
    """Join syllables with spaces, but attach the erhua 'r' to the syllable before it."""
    out: list[str] = []
    for p in parts:
        if p == "r" and out:
            out[-1] += "r"
        else:
            out.append(p)
    return " ".join(out)


def to_marks(pinyin: str) -> str:
    """'ni3 hao3' -> 'nǐ hǎo'; 'yi1 dian3 r5' -> 'yī diǎnr'."""
    return join_marked([s.marked for s in parse_numbered(pinyin)])


def is_valid(syl: Syllable) -> bool:
    return syl.letters in VALID_SYLLABLES


def split_initial(letters: str) -> tuple[str, str]:
    """'zhong' -> ('zh', 'ong'); 'an' -> ('', 'an')."""
    for ini in INITIALS:
        if letters.startswith(ini) and len(letters) > len(ini):
            return ini, letters[len(ini):]
    return "", letters


@dataclass
class SandhiResult:
    spoken: list[int]  # tones as actually said
    notes: list[str] = field(default_factory=list)


_NUMBER_CHARS = set("零一二三四五六七八九十百千万亿两第")


def apply_sandhi(hanzi: str, syllables: list[Syllable]) -> SandhiResult:
    """Work out the tones as spoken, with a plain-English note per change.

    Rules covered (the standard textbook ones):
      * two or more 3rd tones in a row: all but the last become 2nd tone
      * 不 bù before a 4th tone becomes bú
      * 一 yī becomes yí before a 4th (or neutral) tone and yì before 1st/2nd/3rd,
        but stays yī at the end of a word, after 第, or inside a number like 十一
    """
    tones = [s.tone for s in syllables]
    spoken = list(tones)
    notes: list[str] = []
    chars = list(hanzi) if len(hanzi) == len(syllables) else [""] * len(syllables)

    for i, ch in enumerate(chars):
        nxt = tones[i + 1] if i + 1 < len(tones) else None
        prev = chars[i - 1] if i > 0 else ""
        if ch == "不" and tones[i] == 4 and nxt == 4:
            spoken[i] = 2
            notes.append("不 changes to bú before a 4th tone")
        elif ch == "一" and tones[i] == 1 and nxt is not None and prev not in _NUMBER_CHARS:
            next_ch = chars[i + 1]
            if next_ch in _NUMBER_CHARS:
                continue  # counting, e.g. 一百 is still often said yì bǎi, but skip numbers to stay safe
            if nxt in (4, 5):
                spoken[i] = 2
                notes.append("一 changes to yí before a 4th tone")
            else:
                spoken[i] = 4
                notes.append("一 changes to yì before a 1st, 2nd or 3rd tone")

    i = 0
    while i < len(tones):
        if tones[i] != 3:
            i += 1
            continue
        j = i
        while j + 1 < len(tones) and tones[j + 1] == 3:
            j += 1
        if j > i:
            for k in range(i, j):
                spoken[k] = 2
            if j - i == 1:
                notes.append("Two 3rd tones in a row: the first is said as a 2nd tone")
            else:
                notes.append("Several 3rd tones in a row: all but the last are said as 2nd tones")
        i = j + 1

    return SandhiResult(spoken, notes)


def breakdown(hanzi: str, pinyin: str) -> dict:
    """Everything the entry card's Pronunciation section shows."""
    syls = parse_numbered(pinyin)
    sandhi = apply_sandhi(hanzi, syls)
    parts = []
    chars = list(hanzi) if len(hanzi) == len(syls) else [None] * len(syls)
    for ch, syl, said in zip(chars, syls, sandhi.spoken):
        ini, fin = split_initial(syl.letters)
        parts.append({
            "hanzi": ch,
            "pinyin": syl.marked,
            "initial": ini,
            "final": fin,
            "tone": syl.tone,
            "toneName": TONE_NAMES[syl.tone],
            "spokenTone": said,
        })
    spoken = join_marked(
        [Syllable(s.letters, t, s.capital).marked for s, t in zip(syls, sandhi.spoken)]
    )
    return {
        "syllables": parts,
        "spoken": spoken if sandhi.notes else None,
        "notes": sandhi.notes,
    }
