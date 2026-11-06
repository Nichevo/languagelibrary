# Language Library

An offline Android app (Flutter) for learning Mandarin: a small, checked library of
words and phrases, a Focus list of the ones you are working on, and two-way
flashcards with spaced repetition.

## What's in phase 1

- **Library**: about 2,270 entries (HSK 3.0 levels 1 to 3 plus everyday phrases and sentences), searchable by
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

Every push builds the app on GitHub Actions. Open the latest **CI** run on the
Actions tab, download **language-library-apk**, unzip it, copy `app-release.apk`
to the phone and open it.

Android's Play Protect will warn that it doesn't recognise the app, because it
isn't from the Play Store. Tap **More details → Install anyway**. If that option
isn't shown: Play Store → profile picture → Play Protect → gear → turn off
**Scan apps with Play Protect**, install, then turn it back on.

### One-time: the signing key

Android only installs an update over the old app if both are signed with the same
key. Without it you would have to uninstall (and lose your stars and progress)
for every update. To set it up once:

1. Actions tab → **Create signing key (run once)** → **Run workflow**.
2. When it finishes, download **signing-key-keep-private** from the run and unzip it.
3. Repo **Settings → Secrets and variables → Actions → New repository secret**, twice:
   - `ANDROID_KEYSTORE_BASE64`: paste the contents of `ANDROID_KEYSTORE_BASE64.txt`
   - `ANDROID_KEYSTORE_PASSWORD`: paste the contents of `ANDROID_KEYSTORE_PASSWORD.txt`
4. Keep the unzipped folder somewhere safe (a password manager is ideal), then
   delete the download from the workflow run.

From then on every build is signed with that key. The first signed build needs one
uninstall of any older test build; after that, updates install over the top.

To build yourself: install [Flutter](https://docs.flutter.dev/get-started/install),
then `cd app && flutter run` with the phone plugged in.

## Rebuilding the word data

```
python3 -m tools.build_data                  # HSK levels 1-3 + phrases
python3 -m tools.build_data --levels new-1 new-2 new-3 new-4   # add HSK level 4
```

The script downloads the HSK list and CC-CEDICT. A word is kept only if both sources
agree on its characters and pinyin, every syllable is a real Mandarin syllable, and
CC-CEDICT has a real meaning for it. Everything dropped or flagged is listed in
`tools/build_report.md`.

### Sentences

`tools/sources/tatoeba_cmn_eng.tsv` holds native-speaker Mandarin sentences with
English translations from Tatoeba. To refresh it, run the **Fetch Tatoeba sentences**
workflow in the Actions tab (it commits the new file), or `python3 -m tools.fetch_tatoeba`
on a machine that can reach tatoeba.org. The phrasebook is the list of Tatoeba
numbers in `tools/sources/sentences.tsv`; add a number there to add a sentence.
The build fills in the pinyin and leaves out, with a reason in the report, any
sentence it can't read with certainty.

## Making the voices (one time, on your computer)

### On Windows, the easy way

Needs [Git](https://git-scm.com/download/win) and Miniconda or Anaconda, plus the
Google Cloud project described below. The Google Cloud command-line tools are added to
the conda environment automatically.

1. Get the project once, from a command prompt:
   `git clone https://github.com/Nichevo/languagelibrary D:\LanguageLibrary`
2. Double-click `windows\make-voices.bat`. The first time it creates the
   `languagelibrary` conda environment, signs you in to Google Cloud, makes voice
   samples for you to pick from, then makes every clip and checks it. It sends the
   clips to GitHub on a new branch and opens the page to make the pull request.
3. Double-click `windows\update.bat` whenever there are changes, to get them. It also
   updates the conda environment and offers to make voices for any new words.

### By hand

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
for you to listen to. About 2,270 entries × 2 voices uses roughly 10,000 characters,
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
