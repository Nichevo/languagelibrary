# Credits

This is a personal app, but every source is credited as if it were public.
The same list appears in the app under Practice → About, sources and credits,
and the full license texts ship in `app/assets/licenses/`.

| What | Source | License | Used for |
| --- | --- | --- | --- |
| Word list | [complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) | MIT | Which words are in the starter set, HSK level, frequency |
| Dictionary | [CC-CEDICT](https://cc-cedict.org/wiki/) by MDBG and contributors | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | Every pinyin, meaning, measure word and traditional form in the app |
| Opposites | [WordNet 3.1](https://wordnet.princeton.edu/) by Princeton University | [WordNet licence](https://wordnet.princeton.edu/license-and-commercial-use) | Checking that opposite pairs (大 big / 小 small) are antonyms in English |
| Key sounds tips | Wikipedia, [Standard Chinese phonology](https://en.wikipedia.org/wiki/Standard_Chinese_phonology) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | The short "how to tell them apart" tips in Practice > Key sounds (`tools/sources/sound_tips.tsv`), summarised from the article; each tip lists the sentences it is based on |
| Voices | [Google Cloud Text-to-Speech](https://cloud.google.com/text-to-speech) | Google Cloud terms | Female and male audio clips |
| Audio check | [Google Cloud Speech-to-Text](https://cloud.google.com/speech-to-text) | Google Cloud terms | Checking each clip says the right word |
| Say it recogniser | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) by the k2-fsa project, with its small streaming Zipformer CTC Chinese model (`sherpa-onnx-streaming-zipformer-small-ctc-zh-int8-2025-04-01`) | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) (the model came with no separate licence file; it is published by the same project) | Hearing what the learner said, on the device, in the Say it practice |

## Share-alike note

`app/assets/data/library.json` contains material adapted from CC-CEDICT, so that
file is shared under CC BY-SA 4.0 too. Our own additions (topic tags, the reading
choices in `tools/sources/readings.tsv`, the phrase list in
`tools/sources/phrases.tsv`, the tone-set fill list in `tools/sources/tone_words.tsv`) are included under the same license.
The same goes for `app/assets/data/char_tones.tsv` (every reading CC-CEDICT gives each
character, made by `tools/char_tones.py`), which Say it uses to name what the recogniser heard.

## What is ours

- Topic tags (Food, Travel, Family, Everyday, Numbers) come from keyword rules in
  `tools/sources/topics.tsv`. They help filtering and are not shown as facts.
- Pronunciation breakdowns and tone-change notes are computed from the pinyin by
  fixed rules in `tools/pinyin.py`, with tests.
- Scales in `tools/sources/scales.tsv` (cold → cool → warm → hot): which words go
  together and their order were picked by hand for this app, and the app says so.
  Each word and the meaning shown for it must match the library exactly, or the
  build stops.
- Opposites in `tools/sources/opposites.tsv`: a pair is listed only when the two
  words' CC-CEDICT meanings are antonyms in their most common sense in WordNet 3.1
  (copyright Princeton University; licence text in `app/assets/licenses/WordNet-license.txt`).
  We then removed odd matches by hand; no pair was added from outside that list.
- Where a word has several dictionary readings, `tools/sources/readings.tsv` picks
  the everyday one. The meaning shown always comes from the CC-CEDICT entry for
  that exact reading.
- Tricky sounds: tone sets, same-sound groups and two-reading characters are
  grouped by the app from the pinyin. The extra characters in
  `tools/sources/tone_words.tsv` (烫, 麻 and others from HSK 3.0 levels 7 to 9) were
  picked by hand to fill tone sets; their pinyin and meaning come from CC-CEDICT.

- [Tatoeba](https://tatoeba.org) sentences, licensed
  [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/). Used for the
  phrasebook sentences and the example sentences under each word. Only Mandarin
  sentences added by people whose Tatoeba profile lists Mandarin as their native
  language are used, each with one English translation. Every sentence keeps its
  Tatoeba number and both contributors' usernames, shown in the app under Source.
  Pinyin for these sentences is not from Tatoeba: `tools/sentences.py` looks each
  word up in the library and the HSK list (confirmed by CC-CEDICT) and leaves out
  any sentence with a word it can't read one way only.

- [Chinese Grammar Wiki](https://resources.allsetlearning.com/chinese/grammar/)
  (AllSet Learning, Creative Commons BY-NC-SA, used non-commercially with credit).
  Each sentence pattern in `tools/sources/patterns.json` summarises one of its pages
  in our own words and links to it. The example sentences are Tatoeba phrasebook
  sentences; how they are split into chunks, and the role names, are ours.
- Say it: the recogniser only writes characters. Saying which syllable came out
  wrong ("卖 mài, a 4th tone") is the app comparing those characters' CC-CEDICT
  readings with the word's pinyin. The pitch line is measured on the device (the
  YIN method) and drawn as it is; the app does not mark tones right or wrong from
  it, because on our own voice clips that kind of automatic verdict was wrong too
  often. Recordings stay on the device.
- [Chinese Dialogues Podcast](https://coerll.utexas.edu/coerll/oer/chinese-dialogues-podcast/)
  by Wen-Hua Teng, published by COERLL (The Center for Open Educational Resources
  and Language Learning), The University of Texas at Austin, licensed
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Its 70 beginner
  dialogues are the base of the conversation practice scenes (being built; not in
  the app yet). `tools/fetch_dialogues.py` copies the transcripts' text by machine
  into `tools/sources/coerll/`; `tools/dialogues.py` keeps a line only when its
  simplified and traditional versions agree and every word passes the same
  pinyin check as the Tatoeba sentences. Which lines answer which, and which reply
  is the wrong one, are ours and are checked in English before use.
- Character families are worked out by the app: every library entry that uses
  the character. Nothing is added by hand.

## Planned sources (not used yet)

- [Hanzi Writer](https://github.com/chanind/hanzi-writer) stroke order (code MIT,
  data Arphic Public License), phase 3.
