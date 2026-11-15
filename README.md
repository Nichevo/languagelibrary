# Language Library

An offline Android and iPad app (Flutter) for learning Mandarin: a small, checked library of
words and phrases, a Focus list of the ones you are working on, and two-way
flashcards with spaced repetition.

## What's in phase 1

- **Library**: about 5,600 entries (HSK 3.0 levels 1 to 6, everyday phrases and 449 phrasebook sentences). Levels 4 to 6
  start switched off; turn them on in Practice → Settings → Levels and content. Searchable by
  English, pinyin (with or without tones) or hanzi, with topic filters: Everyday,
  Food, Travel, Family, Numbers.
- **Word page**: big hanzi, tone-coloured pinyin, meanings, measure words, female
  and male voice, slow playback, a per-syllable pronunciation breakdown, tone-change
  notes (你好 is said ní hǎo), source label and a "Report a problem" button.
- **Focus list**: star words; optional custom lists such as "This week".
- **Practice**: every word has a Chinese → English card and an English → Chinese
  card. Again / Hard / Good / Easy decides when each comes back.
- **Learning journey** (optional, offered on the Practice tab): a focus each week that grows
  from the words you already have. Next words are picked by how they link to yours: characters
  you know, phrasebook sentences with only one word missing, the dictionary's related words,
  topics and sentence patterns, and each suggestion says why. Paths (Connections, Topics,
  Characters, Sentences, HSK gaps) take turns, with a review week every fourth week. Words you
  find yourself count too. Progress shows as a word web on the Progress tab, and the app's
  colour changes at each milestone (150, 400, 900, 1,800, 3,000 and 5,000 words known).
  Settings → Learning journey changes the paths, pace and colours, or turns it off.
- Simplified characters only for now; traditional forms are already stored.

## Layout

```
app/                 Flutter app
  assets/data/       library.json (built by tools/build_data.py), char_tones.tsv (tools/char_tones.py)
  assets/audio/      voice clips + manifest.json (made by tools/generate_audio.py),
                     pitch_refs.json (each clip's pitch line, tools/pitch_refs.py)
  assets/licenses/   full license texts (tools/fetch_licenses.py)
  assets/speech/     the Say it speech recogniser's model (sherpa-onnx, see CREDITS.md)
tools/               Python scripts that build the data and audio
  sources/           our small hand-kept lists (phrases, reading choices, topic rules)
  build_report.md    what the last data build dropped or flagged
```

## Installing on your phone

Every push to `main` builds the app on GitHub Actions and replaces the
**android-latest** release. On the phone, open the repo's **Releases** page,
download `language-library.apk` and open it.

Builds go to a release rather than an Actions artifact because artifacts count
against the private repo's 0.5 GB Actions storage and release files don't.
Pull requests only run analyze and tests, not the ~12-minute APK build, to stay
inside the free Actions minutes; changes that only touch `.md` files skip CI.

Workflows run with a read-only token. Only the jobs that publish a release (or
commit the Tatoeba file) can write, and pull request runs never get write access
or the signing secrets. Actions are pinned to full commit SHAs, and Dependabot
opens a weekly pull request when actions or packages have new versions.

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

## Installing on your iPad

The iPad app is installed with [AltServer](https://altstore.io) on a Windows PC and
your own Apple ID, so no Mac or App Store is needed.

### Getting the iPad file

Actions tab → **Build iPad app** → **Run workflow**. It takes about 5 minutes on
a Mac that GitHub provides, then puts `LanguageLibrary.ipa` on the repo's
**Releases** page. It isn't run on every change, because each Mac minute uses 10
of the private repo's free Actions minutes (so one build uses about 50).

### First install (about 20 minutes)

1. On the PC, install **iTunes** and **iCloud** from Apple's website (not the
   Microsoft Store versions, which AltServer can't use).
2. Install **AltServer** from altstore.io and start it. It sits in the system tray.
3. Plug in the iPad, unlock it and tap **Trust**. In iTunes, turn on
   **Sync with this iPad over Wi-Fi** so later refreshes work without the cable.
4. AltServer tray icon → **Install AltStore** → your iPad. Sign in with your Apple ID.
5. On the iPad: **Settings → General → VPN & Device Management**, trust your Apple ID.
   If asked, turn on **Settings → Privacy & Security → Developer Mode** and restart.
6. Get `LanguageLibrary.ipa` from the latest release onto the iPad: download it in
   Safari while signed in to GitHub, or download it on the PC and put it in Dropbox
   or iCloud Drive. Then open **AltStore → My Apps → +** and pick the file.

To add a widget: touch and hold the home screen → **Edit → Add Widget** → Language
Library. For the quick-question widget, touch and hold it → **Edit Widget** to choose
the kind of question (or Random).

### Living with a free Apple ID

- Apps installed this way last **7 days**. AltStore refreshes them by itself when the
  PC is on with AltServer running and the iPad is on the same Wi-Fi. If one expires,
  open AltStore and tap **Refresh All**. Your progress stays either way.
- A free Apple ID allows 3 sideloaded apps at a time (AltStore is one) and 10 app IDs
  a week. Language Library uses 2 (the app and its widgets).
- To update, run **Build iPad app** again and install the new `.ipa` the same way.
  Progress stays.

## Rebuilding the word data

```
python3 -m tools.build_data                  # HSK levels 1-6 + phrases
python3 -m tools.build_data --levels new-1 new-2 new-3   # only levels 1-3
```

The script downloads the HSK list and CC-CEDICT. A word is kept only if both sources
agree on its characters and pinyin, every syllable is a real Mandarin syllable, and
CC-CEDICT has a real meaning for it. Everything dropped or flagged is listed in
`tools/build_report.md`.

After rebuilding, refresh the readings Say it uses to name what it heard:

```
python3 -m tools.char_tones
```

After new voice clips, work out their pitch lines (the dotted guide on the Say it
pitch graph; `windows\make-voices.bat` does this for you, and it needs numpy and
ffmpeg):

```
python3 -m tools.pitch_refs
```

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
   samples for you to pick from, then makes every clip and checks it. It also voices
   the HSK 7 to 9 words in `extra/hsk7-9/`, which are kept out of the app for now. It sends the
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
recognition. `--recheck` tries again for any that failed (all of the recogniser's
guesses, a slower recording, and for single-reading words a recording without the
pinyin hint). A clip that still can't be confirmed is listed in `tools/audio_report.md`
and **not played in the app**; the phone's own voice says that word instead. About 2,270 entries × 2 voices uses roughly 10,000 characters,
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
