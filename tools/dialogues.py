#!/usr/bin/env python3
"""Turn the Chinese Dialogues Podcast transcripts into draft conversation scenes.

Source: Chinese Dialogues Podcast, Wen-Hua Teng, COERLL, The University of
Texas at Austin, CC BY 3.0. tools/fetch_dialogues.py saves each transcript as
tools/sources/coerll/epNN.txt. Every Chinese line used here is copied from those
files; nothing is written or changed by hand.

A line is kept only when:
  * its simplified and traditional versions agree character by character
    (CC-CEDICT gives the traditional -> simplified pairs);
  * it has no English letters or digits;
  * every word has exactly one reading in the library or the HSK list
    (the same check as the phrasebook sentences, see sentences.Reader), which
    also leaves out invented names such as 王贵一.

The author's own alternatives become extra right replies: "（or 我认不认识她？）"
gives a whole second sentence, and an optional word such as "(一)" gives the
line with and without it.

The web: a reply's "prompt" is the line just before it. Lines that answer the
same prompt in different dialogues are right replies for each other, and
choosing one carries on in its own dialogue (a branch). A line answering a
different prompt can be the wrong reply.

    python3 -m tools.dialogues [--cedict FILE] [--hsk FILE]

writes tools/sources/coerll/scenes.json (draft, not used by the app yet) and
tools/dialogues_report.md (the English review list).
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

from tools import build_data as bd
from tools import sentences as st

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "tools" / "sources" / "coerll"
OUT_JSON = DIR / "scenes.json"
OUT_REPORT = ROOT / "tools" / "dialogues_report.md"
LIBRARY = ROOT / "app" / "assets" / "data" / "library.json"
CREDIT = ("Chinese Dialogues Podcast by Wen-Hua Teng, COERLL (The Center for Open Educational Resources "
          "and Language Learning), The University of Texas at Austin. CC BY 3.0.")

_SECTION = re.compile(r"(?:Chinese\s+Podcast\s+)?Episode\s*#?\s*(\d+)\s*\((Simplified|Traditional|English)[^)]*\)", re.I)
_DIALOGUE = re.compile(r"Dialogues?\s*#\s*(\d+)", re.I)
_ZH_LABEL = re.compile(r"^\s*([^:：\s][^:：]{0,15}?)\s*[:：]\s*(.*)$")
_EN_LABEL = re.compile(r"(?:(?<=^)|(?<=[\s)\]!?.]))([A-Z][\w.'’]*(?: [\w.'’]+){0,2}?):\s")
_ALT = re.compile(r"[（(]\s*(?:or|=)\s*([^()（）]*?)\s*[）)]")
_OPTIONAL = re.compile(r"[（(]\s*([一-鿿]{1,3})\s*[）)]")
_LATIN = re.compile(r"[A-Za-z0-9]")
_SENTENCE_END = "。？！?!"


def is_hanzi(c: str) -> bool:
    return "一" <= c <= "鿿" or c == "〇"


def _join(a: str, b: str) -> str:
    if a and b and a[-1].isascii() and a[-1].isalnum() and b[0].isascii() and b[0].isalnum():
        return a + " " + b
    return a + b


def _tidy(text: str) -> str:
    """Drop spaces between Chinese characters and punctuation (PDF layout gaps)."""
    text = text.strip()
    return re.sub(r"(?<=[^\x00-\x7f]) +(?=[^\x00-\x7f])|(?<=[^\x00-\x7f]) +(?=[(（])|(?<=[)）]) +(?=[^\x00-\x7f])", "", text)


# ---------------------------------------------------------------- parsing

def split_sections(text: str) -> dict[str, dict[int, str]]:
    """{'Simplified'|'Traditional'|'English': {dialogue number: block text}}"""
    marks = list(_SECTION.finditer(text))
    out: dict[str, dict[int, str]] = {}
    for i, m in enumerate(marks):
        body = text[m.end(): marks[i + 1].start() if i + 1 < len(marks) else len(text)]
        kind = m.group(2).capitalize()
        blocks = out.setdefault(kind, {})
        ds = list(_DIALOGUE.finditer(body))
        for j, d in enumerate(ds):
            blocks[int(d.group(1))] = body[d.end(): ds[j + 1].start() if j + 1 < len(ds) else len(body)]
    return out


def chinese_turns(block: str) -> list[dict]:
    turns: list[dict] = []
    for raw in block.replace("\f", "\n").splitlines():
        line = raw.strip()
        if not line:
            continue
        m = _ZH_LABEL.match(line)
        if m and not any(c in m.group(1) for c in "，。？！,?!…"):
            turns.append({"speaker": m.group(1).strip(), "raw": m.group(2).strip()})
        elif turns:
            turns[-1]["raw"] = _join(turns[-1]["raw"], line)
    for t in turns:
        t["raw"] = _tidy(t["raw"])
    return turns


def english_turns(block: str) -> tuple[str, list[dict]]:
    """(scene note before the first speaker, turns)."""
    flat = re.sub(r"\s+", " ", block.replace("\f", " ")).strip()
    marks = list(_EN_LABEL.finditer(flat))
    note = flat[: marks[0].start()].strip() if marks else flat
    turns = []
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(flat)
        turns.append({"speaker": m.group(1), "text": flat[m.end(): end].strip()})
    return note.strip("() "), turns


def variants(raw: str) -> tuple[str, list[str]]:
    """(main line, the author's alternative sentences)."""
    alts = []
    for m in _ALT.finditer(raw):
        alt = _tidy(m.group(1))
        if alt and alt[-1] in _SENTENCE_END and is_hanzi(alt[0]):
            alts.append(alt)
    main = _tidy(_ALT.sub("", raw))
    groups = _OPTIONAL.findall(main)
    with_words = _OPTIONAL.sub(lambda m: m.group(1), main)
    if len(groups) == 1:
        alts.append(_OPTIONAL.sub("", main))
    return with_words, [a for a in dict.fromkeys(alts) if a != with_words]


def parse_episode(episode: str, text: str) -> list[dict]:
    sec = split_sections(text)
    dialogues = []
    for num in sorted(sec.get("Simplified", {})):
        simp = chinese_turns(sec["Simplified"][num])
        trad = chinese_turns(sec.get("Traditional", {}).get(num, ""))
        note, eng = english_turns(sec.get("English", {}).get(num, ""))
        problems = []
        if len(trad) != len(simp):
            problems.append(f"{len(simp)} simplified lines but {len(trad)} traditional")
        if len(eng) != len(simp):
            problems.append(f"{len(simp)} Chinese lines but {len(eng)} English")
        lines = []
        for i, t in enumerate(simp):
            lines.append({
                "id": f"d{num}.{i + 1}",
                "speaker": t["speaker"],
                "raw": t["raw"],
                "traditional": trad[i]["raw"] if len(trad) == len(simp) else None,
                "en": eng[i]["text"] if len(eng) == len(simp) else None,
            })
        dialogues.append({"num": num, "episode": episode, "note": note, "problems": problems, "lines": lines})
    return dialogues


def load_all(folder: Path = DIR) -> list[dict]:
    out = []
    for path in sorted(folder.glob("ep*.txt")):
        out += parse_episode(path.stem[2:], path.read_text(encoding="utf-8"))
    return sorted(out, key=lambda d: d["num"])


# ---------------------------------------------------------------- checks

def trad_to_simp(cedict: list[dict]) -> dict[str, set[str]]:
    m: dict[str, set[str]] = defaultdict(set)
    for e in cedict:
        if len(e["traditional"]) == len(e["simplified"]):
            for t, s in zip(e["traditional"], e["simplified"]):
                m[t].add(s)
    return m


def scripts_agree(simp: str, trad: str | None, t2s: dict[str, set[str]]) -> str:
    """'' if they agree, else why not."""
    if trad is None:
        return "no matching traditional line"
    a = [c for c in _ALT.sub("", simp) if is_hanzi(c)]
    b = [c for c in _ALT.sub("", trad) if is_hanzi(c)]
    if len(a) != len(b):
        return f"simplified and traditional differ: {simp} / {trad}"
    for s, t in zip(a, b):
        if s != t and s not in t2s.get(t, ()):
            return f"simplified and traditional differ at {s} / {t}: {simp} / {trad}"
    return ""


def word_levels(library: list[dict], hsk: list[dict]) -> dict[str, int]:
    lv: dict[str, int] = {}
    for w in hsk:
        nums = [int(x.split("-")[1]) for x in w.get("level", []) if x.startswith("new-") and x.split("-")[1].isdigit()]
        if nums:
            lv[w["simplified"]] = min(nums + [lv.get(w["simplified"], 99)])
    for e in library:
        if e.get("kind", "word") == "word" and e.get("hsk"):
            lv[e["simplified"]] = min(e["hsk"], lv.get(e["simplified"], 99))
    return lv


def check_line(text: str, reader: st.Reader, levels: dict[str, int]) -> dict:
    if _LATIN.search(text):
        return {"ok": False, "why": "has English letters or digits"}
    tokens, why = reader.read(text)
    if tokens is None:
        return {"ok": False, "why": why}
    words = [w for w, n in tokens if n is not None]
    pinyin, numbered = st._pinyin_text(tokens)
    lv = {w: level_of(w, levels) for w in words}
    return {"ok": True, "why": "", "pinyin": pinyin, "pinyinNumbered": numbered, "words": words,
            "hsk": max(lv.values(), default=1), "beyond": [w for w in words if lv[w] > 2]}


def level_of(word: str, levels: dict[str, int]) -> int:
    """HSK level of a word; a set phrase such as 你好 that isn't on the list takes its hardest character's."""
    if word in levels:
        return levels[word]
    return max((levels.get(c, 99) for c in word), default=99)


def check_all(dialogues: list[dict], reader: st.Reader, t2s, levels) -> None:
    for d in dialogues:
        for ln in d["lines"]:
            main, alts = variants(ln["raw"])
            ln["zh"] = main
            agree = scripts_agree(ln["raw"], ln["traditional"], t2s)
            ln.update(check_line(main, reader, levels))
            if ln["ok"] and agree:
                ln.update(ok=False, why=agree)
            if ln["ok"] and not ln["en"]:
                ln.update(ok=False, why="no English line to match it")
            ln["alts"] = []
            for a in alts:
                c = check_line(a, reader, levels)
                if c["ok"]:
                    ln["alts"].append({"zh": a, "pinyin": c["pinyin"], "pinyinNumbered": c["pinyinNumbered"]})


# ---------------------------------------------------------------- the web

def prompt_key(text: str) -> str:
    """Same question, whatever the punctuation or a polite 请问 in front."""
    core = "".join(c for c in text if is_hanzi(c))
    return core[2:] if core.startswith("请问") else core


def _hanzi(text: str) -> str:
    return "".join(ch for ch in text if "\u4e00" <= ch <= "\u9fff")


def echoes(prompt: str, reply: str) -> bool:
    """True when the reply, or one sentence of it, mostly repeats the prompt
    (他们都很好。你哥哥、弟弟呢？ after 他们都很好。)."""
    p = _hanzi(prompt)
    parts = [_hanzi(x) for x in re.split(r"[。！？!?，,；;]", reply)] + [_hanzi(reply)]
    for r in parts:
        if len(r) >= 2 and sum(1 for ch in r if ch in p) / len(r) >= 0.6:
            return True
    return False


def build_web(dialogues: list[dict]) -> dict:
    """Right and wrong replies for every line that answers the line before it."""
    lines = {ln["id"]: ln for d in dialogues for ln in d["lines"]}
    by_prompt: dict[str, list[str]] = defaultdict(list)
    for d in dialogues:
        ls = d["lines"]
        for i in range(1, len(ls)):
            ls[i]["prompt"] = ls[i - 1]["id"]
            if ls[i]["ok"] and ls[i - 1]["ok"]:
                by_prompt[prompt_key(ls[i - 1]["zh"])].append(ls[i]["id"])

    def next_ok(lid: str) -> str | None:
        d, i = lid[1:].split(".")
        nxt = f"d{d}.{int(i) + 1}"
        return nxt if nxt in lines and lines[nxt]["ok"] else None

    turns = {}
    pool = sorted({lid for ids in by_prompt.values() for lid in ids}, key=_order)
    for d in dialogues:
        for ln in d["lines"][1:]:
            prompt = lines[ln["prompt"]]
            if not (ln["ok"] and prompt["ok"]):
                continue
            key = prompt_key(prompt["zh"])
            right = [{"line": ln["id"], "zh": ln["zh"], "next": next_ok(ln["id"])}]
            for a in ln["alts"]:
                right.append({"line": ln["id"], "zh": a["zh"], "alt": True, "next": next_ok(ln["id"])})
            others = [o for o in by_prompt[key] if o != ln["id"] and lines[o]["zh"] not in {r["zh"] for r in right}]
            others.sort(key=lambda o: (next_ok(o) is None, _order(o)))
            for o in others[: max(0, 2 - len(right))]:
                right.append({"line": o, "zh": lines[o]["zh"], "next": next_ok(o), "branch": next_ok(o) != next_ok(ln["id"])})
            right = right[:2]
            pwords = set(prompt.get("words", []))
            asks = is_question(ln["zh"])
            wrong = [w for w in pool if prompt_key(lines[lines[w]["prompt"]]["zh"]) != key
                     and _order(w)[0] != d["num"]
                     and is_question(lines[w]["zh"]) == asks
                     and lines[w]["zh"] not in {r["zh"] for r in right}
                     and lines[w]["hsk"] <= max(ln["hsk"], 2)]
            # A wrong reply must not just repeat the question: drop lines that mostly
            # reuse the characters of the line before (他们忙吗？ offered for 他们忙吗？).
            wrong = [w for w in wrong if not echoes(prompt["zh"], lines[w]["zh"])]
            size = len(ln["zh"])
            # Most plausible first: shares words with the line before, and is about as long as the right reply.
            wrong.sort(key=lambda w: (-len(pwords & set(lines[w]["words"])), abs(len(lines[w]["zh"]) - size) // 4, _order(w)))
            # Two wrong replies wherever there is only one right one, so every turn offers three.
            turns[ln["id"]] = {"prompt": prompt["id"], "right": right, "wrong": wrong[:3 - len(right)]}
    return turns


def tatoeba_index(pairs: list[dict], reader: st.Reader, levels: dict[str, int]) -> list[dict]:
    out = []
    for p in pairs:
        c = check_line(p["cmn"], reader, levels)
        if c["ok"]:
            out.append({**c, "zh": p["cmn"], "en": p["eng"], "credit": st.credit(p), "id": p["cmn_id"]})
    return out


def fill_from_tatoeba(turns: dict, lines: dict, index: list[dict]) -> None:
    """A second right reply where the dialogues have none: a Tatoeba sentence that
    is the same reply with a short addition after a comma, such as 我很好。 ->
    我很好，谢谢。 Looser matches (sharing words) turned out to change the meaning
    too often, so they are not used."""
    by_text = defaultdict(list)
    for t in index:
        head = re.split(r"[，,]", t["zh"], maxsplit=1)
        if len(head) == 2 and head[1].strip():
            by_text[head[0]].append(t)
    for lid, turn in turns.items():
        if len(turn["right"]) >= 2:
            continue
        ln = lines[lid]
        core = ln["zh"].rstrip("。！？!?.")
        if "，" in core or "," in core:
            continue
        cands = [t for t in by_text.get(core, []) if is_question(t["zh"]) == is_question(ln["zh"])
                 and t["hsk"] <= max(ln["hsk"], 2) and sum(map(is_hanzi, t["zh"])) <= sum(map(is_hanzi, core)) + 4
                 and t["zh"] not in {r["zh"] for r in turn["right"]}]
        if cands:
            t = min(cands, key=lambda t: (len(t["zh"]), int(t["id"])))
            turn["right"].append({"tatoeba": t["id"], "zh": t["zh"], "en": t["en"], "pinyin": t["pinyin"],
                                  "credit": t["credit"], "next": turn["right"][0]["next"]})
            turn["wrong"] = turn["wrong"][:1]


def is_question(text: str) -> bool:
    return text.rstrip()[-1:] in "？?"


def _order(lid: str) -> tuple[int, int]:
    d, i = lid[1:].split(".")
    return int(d), int(i)


# ---------------------------------------------------------------- scenes and report

def scene_length(d: dict) -> int:
    """How many lines from the start can be used (stops at the first line that failed)."""
    n = 0
    for ln in d["lines"]:
        if not ln["ok"]:
            break
        n += 1
    return n


def build_output(dialogues: list[dict], turns: dict) -> dict:
    keep = ("id", "speaker", "zh", "pinyin", "pinyinNumbered", "en", "hsk", "alts", "ok", "why")
    scenes = []
    for d in dialogues:
        n = scene_length(d)
        if n >= 2:
            scenes.append({"id": f"d{d['num']}", "dialogue": d["num"], "episode": d["episode"], "note": d["note"],
                           "lines": [ln["id"] for ln in d["lines"][:n]],
                           "hsk": max(ln["hsk"] for ln in d["lines"][:n])})
    return {
        "source": CREDIT,
        "status": "draft: each scene is checked in English before the app uses it",
        "lines": {ln["id"]: {k: ln.get(k) for k in keep} for d in dialogues for ln in d["lines"]},
        "turns": turns,
        "scenes": scenes,
    }


def write_report(dialogues: list[dict], turns: dict, out: dict, path: Path = OUT_REPORT) -> None:
    lines = {ln["id"]: ln for d in dialogues for ln in d["lines"]}
    all_lines = list(lines.values())
    ok = [ln for ln in all_lines if ln["ok"]]
    full = [d for d in dialogues if all(ln["ok"] for ln in d["lines"])]
    easy = [d for d in full if max(ln["hsk"] for ln in d["lines"]) <= 2]
    two = [t for t in turns.values() if len(t["right"]) == 2]
    branches = [t for t in turns.values() if any(r.get("branch") for r in t["right"])]
    why = defaultdict(int)
    for ln in all_lines:
        if not ln["ok"]:
            why[re.sub(r":.*", "", ln["why"]).split(" at ")[0]] += 1
    r = ["# Dialogue scenes: review list", "",
         f"Source: {CREDIT}", "",
         "Made by `python3 -m tools.dialogues` from the transcripts in tools/sources/coerll. "
         "Nothing below is in the app yet: each scene is checked in English first.", "",
         "## Summary", "",
         f"- Dialogues: {len(dialogues)}, lines: {len(all_lines)}",
         f"- Lines that pass every check: {len(ok)} ({len(ok) * 100 // max(1, len(all_lines))}%)",
         f"- Dialogues where every line passes: {len(full)}, of which {len(easy)} use only HSK 1-2 words",
         f"- Scenes (a dialogue's usable lines from the start, 2 or more): {len(out['scenes'])}",
         f"- Reply turns: {len(turns)}; with two right replies: {len(two)}; with a branch into another dialogue: {len(branches)}",
         f"- Second right replies taken from Tatoeba: {sum(1 for t in turns.values() for o in t['right'] if 'tatoeba' in o)}",
         f"- Reply turns with only one right reply: {len(turns) - len(two)}",
         "", "Why lines were left out:", ""]
    r += [f"- {k}: {v}" for k, v in sorted(why.items(), key=lambda kv: -kv[1])]
    problems = [d for d in dialogues if d["problems"]]
    if problems:
        r += ["", "## Dialogues whose lines didn't line up", ""]
        r += [f"- #{d['num']}: {'; '.join(d['problems'])}" for d in problems]
    mism = [ln for ln in all_lines if ln["why"].startswith("simplified and traditional")]
    if mism:
        r += ["", "## Simplified and traditional disagree (left out; the recording decides)", ""]
        r += [f"- {ln['id']}: {ln['why']}" for ln in mism]
    r += ["", "## Scenes to check", "",
          "For each reply turn: does each ✓ reply answer the line before it, and does the ✗ reply not answer it?", ""]
    for s in out["scenes"]:
        level = f"up to HSK {s['hsk']}" if s["hsk"] < 99 else "has a word outside the HSK list"
        r += [f"### Dialogue {s['dialogue']} (episode {s['episode']}, {level})", ""]
        if s["note"]:
            r += [f"_{s['note']}_", ""]
        for lid in s["lines"]:
            ln = lines[lid]
            r.append(f"- **{ln['speaker']}**: {ln['zh']} ({ln['pinyin']}) {ln['en']}")
            t = turns.get(lid)
            if t:
                for opt in t["right"]:
                    if "tatoeba" in opt:
                        r.append(f"  - ✓ {opt['zh']} {opt['en']} (Tatoeba #{opt['tatoeba']}, check this one)")
                        continue
                    src = lines[opt["line"]]
                    tag = " (author's alternative)" if opt.get("alt") else ("" if opt["line"] == lid else f" (from {opt['line']}, then carries on there)" if opt.get("branch") else f" (from {opt['line']})")
                    r.append(f"  - ✓ {opt['zh']} {src['en'] if not opt.get('alt') else ''}{tag}")
                for wid in t["wrong"]:
                    w = lines[wid]
                    r.append(f"  - ✗ {w['zh']} {w['en']} (from {w['id']})")
        r.append("")
    left = [ln for ln in all_lines if not ln["ok"]]
    r += ["## Lines left out", ""]
    r += [f"- {ln['id']} {ln['zh'] if 'zh' in ln else ln['raw']}: {ln['why']}" for ln in left]
    path.write_text("\n".join(r) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cedict", help="local CC-CEDICT file (default: download from MDBG)")
    ap.add_argument("--hsk", help="local complete.json (default: download)")
    args = ap.parse_args(argv)
    dialogues = load_all()
    if not dialogues:
        raise SystemExit("no transcripts in tools/sources/coerll: run python3 -m tools.fetch_dialogues first")
    cedict = bd.load_cedict(args.cedict)
    hsk = bd.load_hsk(args.hsk)
    library = [e for e in json.loads(LIBRARY.read_text(encoding="utf-8"))["entries"]]
    reader = st.Reader(cedict, library, hsk)
    levels = word_levels(library, hsk)
    check_all(dialogues, reader, trad_to_simp(cedict), levels)
    turns = build_web(dialogues)
    pairs = st.load_pairs()
    if pairs:
        fill_from_tatoeba(turns, {ln["id"]: ln for d in dialogues for ln in d["lines"]},
                          tatoeba_index(pairs, reader, levels))
    out = build_output(dialogues, turns)
    OUT_JSON.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    write_report(dialogues, turns, out)
    print(f"{len(dialogues)} dialogues, {len(out['scenes'])} scenes, {len(turns)} reply turns -> {OUT_REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
