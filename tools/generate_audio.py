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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "app" / "assets" / "data" / "library.json"
AUDIO_DIR = ROOT / "app" / "assets" / "audio"
MANIFEST = AUDIO_DIR / "manifest.json"
REPORT = Path(__file__).resolve().parent / "audio_report.md"
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


def char_readings_from_library(entries) -> dict[str, set[str]]:
    """Toneless readings per character, from the library itself (good enough for the check)."""
    out: dict[str, set[str]] = {}
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


def synthesize(tts_mod, client, hanzi: str, numbered: str | None, voice: str, encoding) -> bytes:
    """With `numbered`, the voice is told the exact pinyin. Sentences pass None and are read as written."""
    if numbered is None:
        req = tts_mod.SynthesizeSpeechRequest(
            input=tts_mod.SynthesisInput(text=hanzi),
            voice=tts_mod.VoiceSelectionParams(language_code=LANG, name=voice),
            audio_config=tts_mod.AudioConfig(audio_encoding=encoding, sample_rate_hertz=24000),
        )
        return client.synthesize_speech(request=req).audio_content
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
        audio_config=tts_mod.AudioConfig(audio_encoding=encoding, sample_rate_hertz=24000),
    )
    return client.synthesize_speech(request=req).audio_content


def transcribe(speech_mod, client, wav: bytes) -> str:
    config = speech_mod.RecognitionConfig(
        encoding=speech_mod.RecognitionConfig.AudioEncoding.LINEAR16,
        sample_rate_hertz=24000,
        language_code=STT_LANG,
    )
    resp = client.recognize(config=config, audio=speech_mod.RecognitionAudio(content=wav))
    return "".join(r.alternatives[0].transcript for r in resp.results if r.alternatives)


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
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() and not force else {"voices": {}, "clips": {}}
    manifest["voices"] = {"female": female, "male": male}

    todo = entries[:limit] if limit else entries
    for n, e in enumerate(todo, 1):
        for key, voice in (("f", female), ("m", male)):
            file = f"{e['id']}_{key}.mp3"
            clip_key = f"{e['id']}_{key}"
            if not force and (AUDIO_DIR / file).exists() and clip_key in manifest["clips"]:
                continue
            pinyin_hint = None if e.get("kind") == "sentence" else e["pinyinNumbered"]
            mp3 = synthesize(tts_mod, tts, e["simplified"], pinyin_hint, voice, tts_mod.AudioEncoding.MP3)
            wav = synthesize(tts_mod, tts, e["simplified"], pinyin_hint, voice, tts_mod.AudioEncoding.LINEAR16)
            heard = transcribe(speech_mod, stt, wav)
            verdict = judge(strip_punct(e["simplified"]), e["pinyinNumbered"], heard, readings)
            (AUDIO_DIR / file).write_bytes(mp3)
            manifest["clips"][clip_key] = {"file": file, "heard": heard, "check": verdict}
        if n % 25 == 0:
            print(f"{n}/{len(todo)} entries done")
            MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
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
        f"{len(manifest['clips'])} clips. Speech recognition heard something different in {len(bad)}; "
        f"{len(similar)} came back as a same-sounding word (usually fine).",
        "",
        "## Listen to these",
        "",
        *(bad or ["- none"]),
        "",
        "## Same sound, different characters (usually fine)",
        "",
        *(similar or ["- none"]),
        "",
    ]), encoding="utf-8")
    print(f"Wrote {REPORT.relative_to(ROOT)}: {len(bad)} clips to listen to.")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--samples", action="store_true")
    ap.add_argument("--female", help="female voice name, from --list-voices")
    ap.add_argument("--male", help="male voice name, from --list-voices")
    ap.add_argument("--force", action="store_true", help="remake clips that already exist")
    ap.add_argument("--limit", type=int, help="only the first N entries (for a quick test)")
    args = ap.parse_args(argv)

    entries = json.loads(LIBRARY.read_text(encoding="utf-8"))["entries"]
    tts_mod, speech_mod = _clients()
    if args.list_voices:
        cmd_list(tts_mod)
    elif args.samples:
        cmd_samples(tts_mod, entries)
    elif args.female and args.male:
        cmd_generate(tts_mod, speech_mod, entries, args.female, args.male, args.force, args.limit)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
