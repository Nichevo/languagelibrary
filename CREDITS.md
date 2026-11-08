# Credits

This is a personal app, but every source is credited as if it were public.
The same list appears in the app under Practice → About, sources and credits,
and the full license texts ship in `app/assets/licenses/`.

| What | Source | License | Used for |
| --- | --- | --- | --- |
| Word list | [complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) | MIT | Which words are in the starter set, HSK level, frequency |
| Dictionary | [CC-CEDICT](https://cc-cedict.org/wiki/) by MDBG and contributors | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | Every pinyin, meaning, measure word and traditional form in the app |
| Opposites | [WordNet 3.1](https://wordnet.princeton.edu/) by Princeton University | [WordNet licence](https://wordnet.princeton.edu/license-and-commercial-use) | Checking that opposite pairs (大 big / 小 small) are antonyms in English |
| Voices | [Google Cloud Text-to-Speech](https://cloud.google.com/text-to-speech) | Google Cloud terms | Female and male audio clips |
| Audio check | [Google Cloud Speech-to-Text](https://cloud.google.com/speech-to-text) | Google Cloud terms | Checking each clip says the right word |

## Share-alike note

`app/assets/data/library.json` contains material adapted from CC-CEDICT, so that
file is shared under CC BY-SA 4.0 too. Our own additions (topic tags, the reading
choices in `tools/sources/readings.tsv`, the phrase list in
`tools/sources/phrases.tsv`) are included under the same license.

## What is ours

- Topic tags (Food, Travel, Family, Everyday, Numbers) come from keyword rules in
  `tools/sources/topics.tsv`. They help filtering and are not shown as facts.
- Pronunciation breakdowns and tone-change notes are computed from the pinyin by
  fixed rules in `tools/pinyin.py`, with tests.
- Opposites in `tools/sources/opposites.tsv`: a pair is listed only when the two
  words' CC-CEDICT meanings are antonyms in their most common sense in WordNet 3.1
  (copyright Princeton University; licence text in `app/assets/licenses/WordNet-license.txt`).
  We then removed odd matches by hand; no pair was added from outside that list.
- Where a word has several dictionary readings, `tools/sources/readings.tsv` picks
  the everyday one. The meaning shown always comes from the CC-CEDICT entry for
  that exact reading.

- [Tatoeba](https://tatoeba.org) sentences, licensed
  [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/). Used for the
  phrasebook sentences and the example sentences under each word. Only Mandarin
  sentences added by people whose Tatoeba profile lists Mandarin as their native
  language are used, each with one English translation. Every sentence keeps its
  Tatoeba number and both contributors' usernames, shown in the app under Source.
  Pinyin for these sentences is not from Tatoeba: `tools/sentences.py` looks each
  word up in the library and the HSK list (confirmed by CC-CEDICT) and leaves out
  any sentence with a word it can't read one way only.

## Planned sources (not used yet)

- [Hanzi Writer](https://github.com/chanind/hanzi-writer) stroke order (code MIT,
  data Arphic Public License), phase 3.
