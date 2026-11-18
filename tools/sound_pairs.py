#!/usr/bin/env python3
"""Sound pairs for the Key sounds practice: library words that differ in one sound.

    python3 -m tools.sound_pairs              # writes the pairs and the report
    python3 -m tools.sound_pairs --heard-test # also runs the speech recogniser test

A pair is two single-character library words whose pinyin differs in exactly
one place: the first sound (shì 是 / sì 四), the vowel part (lǜ 绿 / lù 路), or,
for the Tones group, only the tone (táng 糖 / tǎng 躺). Nothing here is a new
fact: the pinyin is the library's own (HSK and CC-CEDICT agree on it), and the
voice clips are the library's own, already confirmed by the speech check.

Left out on purpose:
  * characters with more than one reading (长 cháng / zhǎng), so a clip can
    never be the other reading;
  * words whose female or male clip did not pass the speech check;
  * neutral-tone words, and words outside HSK levels 1 to 6.

--heard-test plays both voices of every word in a pair to the same on-device
recogniser the app uses (sherpa-onnx, app/assets/speech) and records whether
what it wrote reads like side A, side B, or neither. The app only shows a
"heard" label in Say both for groups where it picks right often enough
(HEARD_PASS). Needs `pip install sherpa-onnx` and ffmpeg.

Outputs:
  app/assets/data/sound_pairs.json   pairs, contrasts, groups, tips
  tools/sources/heard_test.json      the recogniser test result (--heard-test)
  tools/sound_pairs_report.md        counts, tips to check, test result
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "app" / "assets" / "data" / "library.json"
MANIFEST = ROOT / "app" / "assets" / "audio" / "manifest.json"
AUDIO = ROOT / "app" / "assets" / "audio"
CHAR_TONES = ROOT / "app" / "assets" / "data" / "char_tones.tsv"
TIPS = ROOT / "tools" / "sources" / "sound_tips.tsv"
HEARD = ROOT / "tools" / "sources" / "heard_test.json"
OUT = ROOT / "app" / "assets" / "data" / "sound_pairs.json"
REPORT = ROOT / "tools" / "sound_pairs_report.md"
SPEECH = ROOT / "app" / "assets" / "speech"

# Single syllables often come back as a character that reads as neither side
# (or nothing at all). The app then says it couldn't tell. When it does read
# as one side, that side must be the played one on at least HEARD_PASS of
# clips, and it must decide on at least HEARD_DECIDES of them, before a group
# gets the "heard" label.
HEARD_PASS = 0.95
HEARD_DECIDES = 0.6

CONFIRMED = {"exact", "sounds-same"}

# (group id, title, kind, contrasts). kind: "initial" swaps the first sound,
# "final" swaps the vowel part, "tone" swaps the tone. Order is the order shown.
GROUPS = [
    ("tones", "Tones", "tone", [("2", "3"), ("1", "2"), ("1", "4"), ("3", "4"), ("2", "4"), ("1", "3")]),
    ("hiss", "zh ch sh · z c s · j q x", "initial",
     [("sh", "s"), ("zh", "z"), ("ch", "c"), ("j", "zh"), ("q", "ch"), ("x", "sh")]),
    ("puff", "Puffs of air", "initial",
     [("b", "p"), ("d", "t"), ("g", "k"), ("z", "c"), ("zh", "ch"), ("j", "q")]),
    ("u", "ü", "final", [("ü", "i"), ("ü", "u"), ("üe", "ie"), ("üan", "ian"), ("ün", "in")]),
    ("nng", "-n / -ng", "final",
     [("an", "ang"), ("en", "eng"), ("in", "ing"), ("ian", "iang"), ("uan", "uang")]),
]

_TONE_MARKS = {"1": "1st", "2": "2nd", "3": "3rd", "4": "4th"}


def final_of(initial: str, final: str) -> str:
    """The vowel part as it sounds: after j, q, x and y, pinyin writes ü as u."""
    if initial in ("j", "q", "x", "y") and final.startswith("u"):
        return "ü" + final[1:]
    return final


def contrast_id(group: str, a: str, b: str) -> str:
    return f"{group}:{a}/{b}"


def contrast_label(kind: str, a: str, b: str) -> str:
    if kind == "tone":
        return f"{_TONE_MARKS[a]} / {_TONE_MARKS[b]} tone"
    return f"{a} / {b}"


def candidates(entries: list[dict], clips: dict) -> list[dict]:
    """Single-character, single-syllable HSK words with confirmed clips."""
    out = []
    for e in entries:
        syls = e["pronunciation"]["syllables"]
        level = e.get("hsk")
        if len(syls) != 1 or len(e["simplified"]) != 1 or not level or level > 6:
            continue
        if e.get("polyphonic"):
            continue
        s = syls[0]
        if s["tone"] not in (1, 2, 3, 4):
            continue
        if any(clips.get(f"{e['id']}_{v}", {}).get("check") not in CONFIRMED for v in ("f", "m")):
            continue
        out.append({
            "id": e["id"], "hanzi": e["simplified"], "pinyin": e["pinyin"], "level": level,
            "initial": s["initial"], "final": final_of(s["initial"], s["final"]), "tone": s["tone"],
            "frequency": e.get("frequency") or 10 ** 6,
        })
    return out


def build_pairs(words: list[dict]) -> list[dict]:
    """Every pair of sounds that differ in one contrast, with the words for each side.

    Characters that sound the same (是 事 试 shì) share a side, easiest first.
    """
    by_sound: dict[tuple, list[dict]] = defaultdict(list)
    for w in words:
        by_sound[(w["initial"], w["final"], w["tone"])].append(w)
    for ws in by_sound.values():
        ws.sort(key=lambda w: (w["level"], w["frequency"]))

    pairs = []
    for group, _, kind, contrasts in GROUPS:
        for a, b in contrasts:
            for (ini, fin, tone), side_a in sorted(by_sound.items()):
                if kind == "initial":
                    if ini != a:
                        continue
                    other = (b, fin, tone)
                elif kind == "final":
                    if fin != a:
                        continue
                    other = (ini, b, tone)
                else:
                    if str(tone) != a:
                        continue
                    other = (ini, fin, int(b))
                side_b = by_sound.get(other)
                if not side_b:
                    continue
                pairs.append({
                    "contrast": contrast_id(group, a, b),
                    "a": {"pinyin": side_a[0]["pinyin"], "ids": [w["id"] for w in side_a]},
                    "b": {"pinyin": side_b[0]["pinyin"], "ids": [w["id"] for w in side_b]},
                    # The level at which both sides first have a word.
                    "level": max(side_a[0]["level"], side_b[0]["level"]),
                    "_hanzi": (side_a[0]["hanzi"], side_b[0]["hanzi"]),
                })
    return pairs


def read_tips(path: Path = TIPS) -> dict[str, dict]:
    """Group id -> {"text", "source"} from the tips file (tab separated)."""
    tips = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        group, text, source = line.split("\t")
        tips[group] = {"text": text, "source": source}
    return tips


# ---- speech recogniser test ----------------------------------------------

_HAN = re.compile(r"[㐀-鿿]")


def read_char_tones(path: Path = CHAR_TONES) -> dict[str, set[str]]:
    table = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        ch, readings = line.split("\t")
        table[ch] = set(readings.split())
    return table


def numbered(word: dict) -> str:
    return _numbered_syllable(word["initial"], word["final"], word["tone"])


def _numbered_syllable(initial: str, final: str, tone: int) -> str:
    # Back to CC-CEDICT spelling: ü stays ü (char_tones writes nü3, lü4, ju4).
    fin = final
    if initial in ("j", "q", "x", "y") and fin.startswith("ü"):
        fin = "u" + fin[1:]
    return f"{initial}{fin}{tone}"


def side_of(heard: str, a: str, b: str, kind: str, table: dict[str, set[str]]) -> str:
    """Which side the recogniser's first character reads as: "a", "b" or "neither".

    For the tone group the tone must match; otherwise the toneless syllable is
    enough, since the pair already shares its tone.
    """
    m = _HAN.search(heard)
    if not m:
        return "neither"
    readings = table.get(m.group(), set())
    if kind != "tone":
        readings = {r[:-1] for r in readings}
        a, b = a[:-1], b[:-1]
    in_a, in_b = a in readings, b in readings
    if in_a and not in_b:
        return "a"
    if in_b and not in_a:
        return "b"
    return "neither"


def heard_test(words: list[dict], pairs: list[dict]) -> dict:
    import sherpa_onnx  # only needed for the test
    import numpy as np

    rec = sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(
        tokens=str(SPEECH / "tokens.txt"), model=str(SPEECH / "model.int8.onnx"),
        num_threads=2, enable_endpoint_detection=False)
    table = read_char_tones()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))["clips"]
    by_id = {w["id"]: w for w in words}
    cache: dict[str, str] = {}

    def transcribe(clip: str) -> str:
        if clip not in cache:
            pcm = subprocess.run(
                ["ffmpeg", "-v", "quiet", "-i", str(AUDIO / manifest[clip]["file"]),
                 "-f", "f32le", "-ac", "1", "-ar", "16000", "-"],
                check=True, capture_output=True).stdout
            samples = np.frombuffer(pcm, dtype=np.float32)
            s = rec.create_stream()
            # Same padding as the app (lib/speech/recognizer.dart).
            s.accept_waveform(16000, np.zeros(3200, dtype=np.float32))
            s.accept_waveform(16000, samples)
            s.accept_waveform(16000, np.zeros(8000, dtype=np.float32))
            s.input_finished()
            while rec.is_ready(s):
                rec.decode_stream(s)
            cache[clip] = rec.get_result(s).strip()
        return cache[clip]

    kinds = {g: k for g, _, k, _ in GROUPS}
    result: dict[str, dict] = {}
    for p in pairs:
        group = p["contrast"].split(":")[0]
        wa, wb = by_id[p["a"]["ids"][0]], by_id[p["b"]["ids"][0]]
        na, nb = numbered(wa), numbered(wb)
        for side, w in (("a", wa), ("b", wb)):
            for v in ("f", "m"):
                heard = transcribe(f"{w['id']}_{v}")
                got = side_of(heard, na, nb, kinds[group], table)
                r = result.setdefault(p["contrast"], {"right": 0, "wrong": 0, "neither": 0, "misses": []})
                key = "right" if got == side else ("neither" if got == "neither" else "wrong")
                r[key] += 1
                if key != "right" and len(r["misses"]) < 6:
                    r["misses"].append(f"{w['hanzi']} {w['pinyin']} ({v}) → {heard or '(nothing)'}")
    return result


# ---- report ----------------------------------------------------------------

def group_heard(heard: dict, group: str) -> tuple[int, int, int]:
    """Right, wrong side, and total clips for one group."""
    right = wrong = total = 0
    for cid, r in heard.items():
        if cid.split(":")[0] == group:
            right += r["right"]
            wrong += r["wrong"]
            total += r["right"] + r["wrong"] + r["neither"]
    return right, wrong, total


def passes(right: int, wrong: int, total: int) -> bool:
    decided = right + wrong
    return bool(total) and decided / total >= HEARD_DECIDES and right / decided >= HEARD_PASS


def write_report(pairs: list[dict], tips: dict, heard: dict | None) -> str:
    lines = ["# Key sounds: pairs report", "",
             "Made by `python3 -m tools.sound_pairs`. Pairs are library words that differ in one sound "
             "(or only in tone, for Tones). Left out: characters with more than one reading, "
             "unconfirmed clips, neutral tones.", ""]
    lines += ["## Pairs per group", "", "| Group | Contrast | HSK 1-2 | HSK 1-3 | HSK 1-6 | Examples |",
              "|---|---|---:|---:|---:|---|"]
    for group, title, kind, contrasts in GROUPS:
        for a, b in contrasts:
            cid = contrast_id(group, a, b)
            ps = [p for p in pairs if p["contrast"] == cid]
            ex = ", ".join(f"{p['_hanzi'][0]} {p['a']['pinyin']} / {p['_hanzi'][1]} {p['b']['pinyin']}"
                           for p in sorted(ps, key=lambda p: p["level"])[:3])
            lines.append(f"| {title} | {contrast_label(kind, a, b)} | {sum(p['level'] <= 2 for p in ps)} | "
                         f"{sum(p['level'] <= 3 for p in ps)} | {len(ps)} | {ex} |")
    lines += ["", "## Tips to check", "",
              "These are the only new words in Key sounds. Each is summarised from the quoted source. "
              "Please read each one and say if it is fine.", ""]
    for group, title, _, _ in GROUPS:
        t = tips.get(group)
        lines += [f"**{title}**", "", f"> {t['text']}" if t else "> (missing)", "",
                  f"Source: {t['source']}" if t else "", ""]
    lines += ["## Speech recogniser test", ""]
    if not heard:
        lines += ["Not run. Run `python3 -m tools.sound_pairs --heard-test`.", ""]
    else:
        lines += [f"Both voices of the first word on each side of every pair, played to the app's recogniser. "
                  f"\"Neither\" means what it wrote reads as neither word (or it wrote nothing); the app then "
                  f"says it couldn't tell. A group gets the \"heard\" label in Say both only if, when it does "
                  f"decide, it picks the played side at least {HEARD_PASS:.0%} of the time, and it decides on at "
                  f"least {HEARD_DECIDES:.0%} of clips.", "",
                  "| Group | Contrast | Right | Wrong side | Neither | Right when it decides |",
                  "|---|---|---:|---:|---:|---:|"]
        for group, title, kind, contrasts in GROUPS:
            for a, b in contrasts:
                r = heard.get(contrast_id(group, a, b))
                if not r:
                    continue
                d = r["right"] + r["wrong"]
                lines.append(f"| {title} | {contrast_label(kind, a, b)} | {r['right']} | {r['wrong']} | "
                             f"{r['neither']} | {r['right'] / d:.0%} |" if d else
                             f"| {title} | {contrast_label(kind, a, b)} | 0 | 0 | {r['neither']} | – |")
        lines += ["", "| Group | Decides on | Right when it decides | Heard label |", "|---|---:|---:|---|"]
        for group, title, _, _ in GROUPS:
            right, wrong, total = group_heard(heard, group)
            if total:
                d = right + wrong
                lines.append(f"| {title} | {d / total:.0%} of {total} clips | {right / d:.1%} ({wrong} wrong) | "
                             f"{'yes' if passes(right, wrong, total) else 'no'} |")
        lines += ["", "### Some misses", ""]
        for cid, r in heard.items():
            for m in r["misses"][:3]:
                lines.append(f"- {cid}: {m}")
        lines.append("")
    return "\n".join(lines)


def build(heard: dict | None) -> dict:
    data = json.loads(LIBRARY.read_text(encoding="utf-8"))
    clips = json.loads(MANIFEST.read_text(encoding="utf-8"))["clips"]
    words = candidates(data["entries"], clips)
    pairs = build_pairs(words)
    tips = read_tips()
    groups = []
    for group, title, kind, contrasts in GROUPS:
        right, wrong, total = group_heard(heard or {}, group)
        groups.append({
            "id": group, "title": title, "kind": kind,
            "tip": tips[group]["text"], "tipSource": tips[group]["source"],
            "heardCheck": passes(right, wrong, total),
            "contrasts": [{"id": contrast_id(group, a, b), "label": contrast_label(kind, a, b)} for a, b in contrasts],
        })
    out = {
        "note": "Made by tools/sound_pairs.py from library.json. Pinyin from HSK + CC-CEDICT; "
                "tips summarised from Wikipedia (CC BY-SA 4.0).",
        "groups": groups,
        "pairs": [{k: v for k, v in p.items() if not k.startswith("_")} for p in pairs],
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    REPORT.write_text(write_report(pairs, tips, heard), encoding="utf-8")
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--heard-test", action="store_true", help="run the speech recogniser test too")
    args = ap.parse_args()
    heard = None
    if args.heard_test:
        data = json.loads(LIBRARY.read_text(encoding="utf-8"))
        clips = json.loads(MANIFEST.read_text(encoding="utf-8"))["clips"]
        words = candidates(data["entries"], clips)
        heard = heard_test(words, build_pairs(words))
        HEARD.write_text(json.dumps(heard, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    elif HEARD.exists():
        heard = json.loads(HEARD.read_text(encoding="utf-8"))
    out = build(heard)
    print(f"{len(out['pairs'])} pairs -> {OUT.relative_to(ROOT)}; report -> {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
