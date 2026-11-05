# Language Library

An offline Android app (Flutter) for learning Mandarin: a small, checked library of
words and phrases, a Focus list of the ones you are working on, and two-way
flashcards with spaced repetition.

## What's in phase 1

- **Library**: about 540 entries (HSK 3.0 level 1 plus everyday phrases), searchable by
  English, pinyin (with or without tones) or hanzi, with topic filters: Everyday,
  Food, Travel, Family, Numbers.
- **Word page**: big hanzi, tone-coloured pinyin, meanings, measure words, female
  and male voice, slow playback, a per-syllable pronunciation breakdown, tone-change
  notes (你好 is said ní hǎo), source label and a "Report a problem" button.
- **Focus list**: star words; optional custom lists such as "This week".
- **Practice**: every word has a Chinese → English card and an English → Chinese
  card. Again / Hard / Good / Easy decides when each comes back.
- Simplified characters only for now; traditional forms are already stored.

## Layout

```
app/                 Flutter app
  assets/data/       library.json (built by tools/build_data.py)
  assets/audio/      voice clips + manifest.json (made by tools/generate_audio.py)
  assets/licenses/   full license texts (tools/fetch_licenses.py)
tools/               Python scripts that build the data and audio
  sources/           our small hand-kept lists (phrases, reading choices, topic rules)
  build_report.md    what the last data build dropped or flagged
```

## Installing on your phone

Every push builds a debug APK on GitHub Actions. Open the latest **CI** run on the
Actions tab, download **language-library-debug-apk**, unzip it, copy
`app-debug.apk` to the phone and open it (allow "install unknown apps" when asked).

To build yourself: install [Flutter](https://docs.flutter.dev/get-started/install),
then `cd app && flutter run` with the phone plugged in.

## Rebuilding the word data

```
python3 -m tools.build_data                  # HSK level 1 + phrases
python3 -m tools.build_data --levels new-1 new-2   # add HSK level 2
```

The script downloads the HSK list and CC-CEDICT. A word is kept only if both sources
agree on its characters and pinyin, every syllable is a real Mandarin syllable, and
CC-CEDICT has a real meaning for it. Everything dropped or flagged is listed in
`tools/build_report.md`.

## Making the voices (one time, on your computer)

Needs the Google Cloud setup from the plan: a project, billing linked, a US$1 budget
alert, the **Cloud Text-to-Speech API** and **Cloud Speech-to-Text API** enabled, and
the [gcloud CLI](https://cloud.google.com/sdk/docs/install) signed in:

```
gcloud auth application-default login
gcloud config set project YOUR-PROJECT-ID
gcloud auth application-default set-quota-project YOUR-PROJECT-ID

pip install -r tools/requirements-audio.txt
python3 -m tools.generate_audio --samples      # writes tools/audio_samples/index.html
# open that page, listen, pick one female and one male voice, then:
python3 -m tools.generate_audio --female VOICE-NAME --male VOICE-NAME
```

Each clip is made with its exact pinyin, then played back through speech
recognition. Anything that came back different is listed in `tools/audio_report.md`
for you to listen to. About 540 entries × 2 voices uses a few thousand characters,
far inside Google's free monthly allowance. Commit the new files in
`app/assets/audio/` and the app uses them automatically; until then it falls back to
the phone's own Chinese voice.

No keys or credentials are stored in this repo or in the app.

## Tests

```
python3 -m unittest discover -s tools/tests -t .
cd app && flutter analyze && flutter test
```

## Credits

See [CREDITS.md](CREDITS.md).
