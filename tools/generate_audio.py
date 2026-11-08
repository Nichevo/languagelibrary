#!/usr/bin/env python3
"""Make the female and male audio clips with Google Cloud Text-to-Speech.

Run this on your own computer after the one-time Google Cloud setup in README.md.
Nothing here ever goes into the app: the app only gets the finished MP3 files.

    pip install -r tools/requirements-audio.txt
    python3 -m tools.generate_audio --list-voices          # see the Mandarin voices
    python3 -m tools.generate_audio --samples              # 10 words in every voice, to pick by ear
    python3 -m tools.generate_audio --female NAME --male NAME   # make all clips and check them

How a clip is made and checked:
  1. The exact pinyin is passed to the voice with the hanzi, so it cannot guess the
     wrong reading (行 xíng vs háng).
  2. The clip is played back through Google Speech-to-Text.
  3. If the transcript is not the same hanzi (or a same-sounding word), the clip is
     listed in tools/audio_report.md for you to listen to.

Re-running skips clips that already exist, so it is cheap to run again after
adding words. Use --force to remake everything.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "app" / "assets" / "data" / "library.json"
AUDIO_DIR = ROOT / "app" / "assets" / "audio"
MANIFEST = AUDIO_DIR / "manifest.json"
REPORT = Path(__file__).resolve().parent / "audio_report.md"

# Word sets with their own clips. HSK 7-9 is voiced now, while there is cloud
# credit, but kept out of the app (extra/hsk7-9/) until it is wanted.
SETS = {
    "app": (LIBRARY, AUDIO_DIR, REPORT),
    "hsk7-9": (ROOT / "extra" / "hsk7-9" / "library.json", ROOT / "extra" / "hsk7-9" / "audio",
               ROOT / "extra" / "hsk7-9" / "audio_report.md"),
}


def use_set(name: str) -> None:
    """Point LIBRARY, AUDIO_DIR, MANIFEST and REPORT at one word set."""
    global LIBRARY, AUDIO_DIR, MANIFEST, REPORT
    LIBRARY, AUDIO_DIR, REPORT = SETS[name]
    MANIFEST = AUDIO_DIR / "manifest.json"
SAMPLES_DIR = Path(__file__).resolve().parent / "audio_samples"

LANG = "cmn-CN"
STT_LANG = "cmn-Hans-CN"
SAMPLE_WORDS = ["你好", "谢谢", "对不起", "一点儿", "多少", "不是", "行", "朋友", "喜欢", "飞机场"]

_PUNCT = re.compile(r"[\s，。？！、,.?!；;：:\"'“”‘’（）()]")


# ------------------------------------------------------------- checking

def strip_punct(text: str) -> str:
    return _PUNCT.sub("", text)


def toneless(numbered: str) -> str:
    return re.sub(r"[1-5]", "", numbered.lower().replace("u:", "ü").replace("v", "ü")).replace(" ", "")


def judge(expected_hanzi: str, expected_numbered: str, transcript: str, readings: dict[str, set[str]]) -> str:
    """'exact', 'sounds-same' or 'mismatch'.

    'sounds-same' means every transcribed character can be read with the same
    toneless syllable as expected (speech recognition often writes 他 for 她).
    """
    got = strip_punct(transcript)
    if got == expected_hanzi:
        return "exact"
    want = toneless(expected_numbered)
    # recognisers often drop the erhua 儿, so 一点儿 heard as 一点 counts as the same sound
    wants = {want, want[:-1]} if expected_hanzi.endswith("儿") and want.endswith("r") else {want}
    syl_options = [readings.get(ch) for ch in got]
    if got and all(syl_options):
        # try to spell the expected toneless pinyin from the transcript's possible readings
        def can_spell(i: int, rest: str) -> bool:
            if i == len(syl_options):
                return rest == ""
            return any(rest.startswith(s) and can_spell(i + 1, rest[len(s):]) for s in syl_options[i])
        if any(can_spell(0, w) for w in wants):
            return "sounds-same"
    return "mismatch"


CHAR_READINGS = Path(__file__).resolve().parent / "sources" / "char_readings.tsv"


def load_char_readings() -> dict[str, set[str]]:
    """Every toneless reading CC-CEDICT gives each character (tools/sources/char_readings.tsv)."""
    out: dict[str, set[str]] = {}
    if CHAR_READINGS.exists():
        for line in CHAR_READINGS.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                ch, syls = line.split("\t")
                out[ch] = set(syls.split())
    return out


def write_char_readings(cedict: list[dict]) -> int:
    """Rebuilds tools/sources/char_readings.tsv from CC-CEDICT entries (as parsed by build_data)."""
    table: dict[str, set[str]] = {}
    for c in cedict:
        syls = c["pinyin"].lower().replace("u:", "ü").split()
        if len(syls) != len(c["simplified"]):
            continue
        for ch, syl in zip(c["simplified"], syls):
            if re.fullmatch(r"[a-zü]+[1-5]", syl):
                table.setdefault(ch, set()).add(syl[:-1])
    lines = [
        "# Every toneless reading CC-CEDICT gives each character (CC BY-SA 4.0, see CREDITS).",
        "# Made by tools/generate_audio.py --char-readings; used to tell a same-sounding",
        "# transcript from a wrong one when checking recorded audio.",
    ] + [f"{ch}\t{' '.join(sorted(table[ch]))}" for ch in sorted(table)]
    CHAR_READINGS.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(table)


_RANK = {"exact": 0, "sounds-same": 1, "mismatch": 2}


def judge_any(expected_hanzi: str, expected_numbered: str, transcripts: list[str], readings) -> str:
    """The best verdict over speech recognition's alternative transcripts."""
    verdicts = [judge(expected_hanzi, expected_numbered, t, readings) for t in transcripts] or ["mismatch"]
    return min(verdicts, key=_RANK.__getitem__)


def char_readings_from_library(entries) -> dict[str, set[str]]:
    """Toneless readings per character: CC-CEDICT's, plus the library's own."""
    out: dict[str, set[str]] = load_char_readings()
    for e in entries:
        syls = e["pinyinNumbered"].split()
        if len(syls) == len(e["simplified"]):
            for ch, s in zip(e["simplified"], syls):
                out.setdefault(ch, set()).add(toneless(s))
    return out


# ------------------------------------------------------------- google calls

def _clients():
    try:
        from google.cloud import speech, texttospeech
    except ImportError:
        sys.exit("Missing libraries. Run: pip install -r tools/requirements-audio.txt")
    return texttospeech, speech


def list_voices(tts_mod) -> list:
    client = tts_mod.TextToSpeechClient()
    voices = client.list_voices(language_code=LANG).voices
    return sorted(voices, key=lambda v: v.name)


def synthesize(tts_mod, client, hanzi: str, numbered: str | None, voice: str, encoding, rate: float = 1.0) -> bytes:
    """With `numbered`, the voice is told the exact pinyin. Sentences pass None and are read as written."""
    def audio_config():
        if rate == 1.0:
            return tts_mod.AudioConfig(audio_encoding=encoding, sample_rate_hertz=24000)
        return tts_mod.AudioConfig(audio_encoding=encoding, sample_rate_hertz=24000, speaking_rate=rate)

    if numbered is None:
        req = tts_mod.SynthesizeSpeechRequest(
            input=tts_mod.SynthesisInput(text=hanzi),
            voice=tts_mod.VoiceSelectionParams(language_code=LANG, name=voice),
            audio_config=audio_config(),
        )
        return _retry(lambda: client.synthesize_speech(request=req)).audio_content
    pron = tts_mod.CustomPronunciations(pronunciations=[
        tts_mod.CustomPronunciationParams(
            phrase=hanzi,
            phonetic_encoding=tts_mod.CustomPronunciationParams.PhoneticEncoding.PHONETIC_ENCODING_PINYIN,
            pronunciation=numbered,
        )
    ])
    req = tts_mod.SynthesizeSpeechRequest(
        input=tts_mod.SynthesisInput(text=hanzi, custom_pronunciations=pron),
        voice=tts_mod.VoiceSelectionParams(language_code=LANG, name=voice),
        audio_config=audio_config(),
    )
    return _retry(lambda: client.synthesize_speech(request=req)).audio_content


# Google errors that mean "try again shortly" (a brief outage or too many requests).
_TRANSIENT = {"ServiceUnavailable", "DeadlineExceeded", "InternalServerError", "TooManyRequests",
              "ResourceExhausted", "GatewayTimeout", "BadGateway", "RetryError", "ConnectionError"}
RETRY_WAITS = (5, 15, 30, 60, 120, 300)


def _retry(call, waits=RETRY_WAITS, sleep=time.sleep):
    """Run a cloud call, waiting and trying again on a temporary Google error, so a
    short outage doesn't stop a long run. Other errors stop it straight away."""
    for wait in (*waits, None):
        try:
            return call()
        except Exception as exc:  # noqa: BLE001 - only the transient kinds are retried
            if wait is None or type(exc).__name__ not in _TRANSIENT:
                raise
            print(f"  Google says {type(exc).__name__}; trying again in {wait} s...", flush=True)
            sleep(wait)


def transcribe(speech_mod, client, wav: bytes) -> list[str]:
    """What speech recognition heard, best guess first, then up to 4 other guesses."""
    config = speech_mod.RecognitionConfig(
        encoding=speech_mod.RecognitionConfig.AudioEncoding.LINEAR16,
        sample_rate_hertz=24000,
        language_code=STT_LANG,
        max_alternatives=5,
    )
    resp = _retry(lambda: client.recognize(config=config, audio=speech_mod.RecognitionAudio(content=wav)))
    results = [r for r in resp.results if r.alternatives]
    if len(results) == 1:
        return [a.transcript for a in results[0].alternatives]
    return ["".join(r.alternatives[0].transcript for r in results)]


# ------------------------------------------------------------- commands

def cmd_list(tts_mod):
    for v in list_voices(tts_mod):
        gender = tts_mod.SsmlVoiceGender(v.ssml_gender).name.lower()
        print(f"{v.name:40s} {gender}")


def cmd_samples(tts_mod, entries):
    client = tts_mod.TextToSpeechClient()
    SAMPLES_DIR.mkdir(exist_ok=True)
    by_hz = {e["simplified"]: e for e in entries}
    words = [by_hz[w] for w in SAMPLE_WORDS if w in by_hz]
    voices = [v for v in list_voices(tts_mod) if "Chirp3-HD" in v.name] or list_voices(tts_mod)
    rows = []
    for v in voices:
        gender = tts_mod.SsmlVoiceGender(v.ssml_gender).name.lower()
        cells = []
        for e in words:
            name = f"{v.name}_{e['id']}.mp3"
            (SAMPLES_DIR / name).write_bytes(
                synthesize(tts_mod, client, e["simplified"], e["pinyinNumbered"], v.name, tts_mod.AudioEncoding.MP3))
            cells.append(f'<td>{e["simplified"]}<br><audio controls src="{name}"></audio></td>')
        rows.append(f"<tr><th>{v.name}<br><small>{gender}</small></th>{''.join(cells)}</tr>")
        print(f"made samples for {v.name}")
    (SAMPLES_DIR / "index.html").write_text(
        "<meta charset=utf-8><title>Voice samples</title><table border=1 cellpadding=6>"
        + "".join(rows) + "</table>", encoding="utf-8")
    print(f"Open {SAMPLES_DIR / 'index.html'} in a browser and pick one female and one male voice.")


def cmd_generate(tts_mod, speech_mod, entries, female: str, male: str, force: bool, limit: int | None):
    known = {v.name for v in list_voices(tts_mod)}
    for v in (female, male):
        if v not in known:
            sys.exit(f"Voice {v!r} not found. Run with --list-voices to see the choices.")

    tts = tts_mod.TextToSpeechClient()
    stt = speech_mod.SpeechClient()
    readings = char_readings_from_library(entries)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() and not force else {"voices": {}, "clips": {}}
    manifest["voices"] = {"female": female, "male": male}

    todo = entries[:limit] if limit else entries
    for n, e in enumerate(todo, 1):
        for key, voice in (("f", female), ("m", male)):
            file = f"{e['id']}_{key}.mp3"
            clip_key = f"{e['id']}_{key}"
            if not force and (AUDIO_DIR / file).exists() and clip_key in manifest["clips"]:
                # The app shows how much space the audio takes, from these sizes.
                manifest["clips"][clip_key]["bytes"] = (AUDIO_DIR / file).stat().st_size
                continue
            pinyin_hint = None if e.get("kind") == "sentence" else e["pinyinNumbered"]
            mp3 = synthesize(tts_mod, tts, e["simplified"], pinyin_hint, voice, tts_mod.AudioEncoding.MP3)
            wav = synthesize(tts_mod, tts, e["simplified"], pinyin_hint, voice, tts_mod.AudioEncoding.LINEAR16)
            heard = transcribe(speech_mod, stt, wav)
            verdict = judge_any(strip_punct(e["simplified"]), e["pinyinNumbered"], heard, readings)
            (AUDIO_DIR / file).write_bytes(mp3)
            manifest["clips"][clip_key] = {
                "file": file, "bytes": len(mp3), "heard": heard[0] if heard else "", "also": heard[1:], "check": verdict,
            }
        if n % 25 == 0:
            print(f"{n}/{len(todo)} entries done")
            MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    write_report(entries, manifest)


def rejudge(entries, manifest, readings) -> int:
    """Re-checks every clip against what was already heard, with the current rules. No Google calls."""
    by_id = {e["id"]: e for e in entries}
    changed = 0
    for key, c in manifest["clips"].items():
        e = by_id.get(key.rsplit("_", 1)[0])
        if not e:
            continue
        heard = [c.get("heard", "")] + list(c.get("also", []))
        verdict = judge_any(strip_punct(e["simplified"]), e["pinyinNumbered"], heard, readings)
        if _RANK[verdict] < _RANK[c["check"]]:
            c["check"] = verdict
            changed += 1
    return changed


def cmd_recheck(tts_mod, speech_mod, entries, female: str, male: str):
    """Tries again, a few different ways, for every clip that failed the check.

    1. Re-check the same recording, looking at all of speech recognition's guesses.
    2. Record it again a little slower (still with the exact pinyin).
    3. For words with only one possible reading, record it without the pinyin hint,
       since the voice then can't pick a wrong reading anyway.
    A clip that still fails keeps check "mismatch", and the app doesn't play it
    (it uses the phone's own voice for that word instead).
    """
    if not MANIFEST.exists():
        sys.exit("No clips yet. Make them first with --female and --male.")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    readings = char_readings_from_library(entries)
    print(f"{rejudge(entries, manifest, readings)} clips pass with the fuller list of character readings.")
    tts = tts_mod.TextToSpeechClient()
    stt = speech_mod.SpeechClient()
    by_id = {e["id"]: e for e in entries}
    voices = {"f": female, "m": male}
    todo = [k for k, c in manifest["clips"].items() if c["check"] == "mismatch" and k.rsplit("_", 1)[0] in by_id]
    print(f"{len(todo)} clips to try again.")
    fixed = 0
    for n, key in enumerate(todo, 1):
        eid, who = key.rsplit("_", 1)
        e = by_id[eid]
        c = manifest["clips"][key]
        hanzi = strip_punct(e["simplified"])
        sentence = e.get("kind") == "sentence"
        hint = None if sentence else e["pinyinNumbered"]
        attempts = [(hint, 1.0, False), (hint, 0.85, True)]
        if not sentence and not e.get("polyphonic", True):
            attempts.append((None, 1.0, True))
        for numbered, rate, replace in attempts:
            try:
                wav = synthesize(tts_mod, tts, e["simplified"], numbered, voices[who], tts_mod.AudioEncoding.LINEAR16, rate)
                heard = transcribe(speech_mod, stt, wav)
            except Exception as err:  # e.g. a voice that doesn't take a speaking rate
                print(f"  {e['simplified']}: skipped one try ({type(err).__name__})")
                continue
            verdict = judge_any(hanzi, e["pinyinNumbered"], heard, readings)
            if verdict != "mismatch":
                if replace:
                    mp3 = synthesize(tts_mod, tts, e["simplified"], numbered, voices[who], tts_mod.AudioEncoding.MP3, rate)
                    (AUDIO_DIR / c["file"]).write_bytes(mp3)
                    c["bytes"] = len(mp3)
                c.update(heard=heard[0] if heard else "", also=heard[1:], check=verdict)
                fixed += 1
                break
        if n % 25 == 0:
            print(f"{n}/{len(todo)} tried again, {fixed} now pass")
            MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{fixed} of {len(todo)} now pass.")
    write_report(entries, manifest)


def write_report(entries, manifest):
    by_id = {e["id"]: e for e in entries}
    bad, similar = [], []
    for key, c in sorted(manifest["clips"].items()):
        eid, who = key.rsplit("_", 1)
        e = by_id.get(eid)
        if not e:
            continue
        line = f"- {e['simplified']} ({e['pinyin']}), {'female' if who == 'f' else 'male'} voice: heard \"{c['heard']}\" ({c['file']})"
        if c["check"] == "mismatch":
            bad.append(line)
        elif c["check"] == "sounds-same":
            similar.append(line)
    REPORT.write_text("\n".join([
        "# Audio check",
        "",
        f"{len(manifest['clips'])} clips. {len(bad)} could not be confirmed by speech recognition, so the app "
        "does not play them and uses the phone's own voice for those words instead. "
        f"{len(similar)} came back as a same-sounding word, which counts as a pass.",
        "",
        "## Not confirmed (not played in the app)",
        "",
        *(bad or ["- none"]),
        "",
        "## Same sound, different characters (played in the app)",
        "",
        *(similar or ["- none"]),
        "",
    ]), encoding="utf-8")
    print(f"Wrote {REPORT.relative_to(ROOT)}: {len(bad)} clips not confirmed, so not used in the app.")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--samples", action="store_true")
    ap.add_argument("--female", help="female voice name, from --list-voices")
    ap.add_argument("--male", help="male voice name, from --list-voices")
    ap.add_argument("--force", action="store_true", help="remake clips that already exist")
    ap.add_argument("--limit", type=int, help="only the first N entries (for a quick test)")
    ap.add_argument("--recheck", action="store_true", help="try again for clips that failed the check")
    ap.add_argument("--char-readings", metavar="CEDICT", nargs="?", const="",
                    help="rebuild tools/sources/char_readings.tsv (from a local CC-CEDICT file, or download it)")
    ap.add_argument("--set", choices=sorted(SETS), default="app",
                    help="which words: 'app' (the app's library) or 'hsk7-9' (kept in extra/ until wanted)")
    args = ap.parse_args(argv)

    use_set(args.set)
    entries = json.loads(LIBRARY.read_text(encoding="utf-8"))["entries"]
    if args.char_readings is not None:
        from tools.build_data import load_cedict
        print(f"{write_char_readings(load_cedict(args.char_readings or None))} characters written.")
        return
    tts_mod, speech_mod = _clients()
    if args.list_voices:
        cmd_list(tts_mod)
    elif args.samples:
        cmd_samples(tts_mod, entries)
    elif args.recheck and args.female and args.male:
        cmd_recheck(tts_mod, speech_mod, entries, args.female, args.male)
    elif args.female and args.male:
        cmd_generate(tts_mod, speech_mod, entries, args.female, args.male, args.force, args.limit)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
