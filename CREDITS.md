# Credits

This is a personal app, but every source is credited as if it were public.
The same list appears in the app under Practice → About, sources and credits,
and the full license texts ship in `app/assets/licenses/`.

| What | Source | License | Used for |
| --- | --- | --- | --- |
| Word list | [complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) | MIT | Which words are in the starter set, HSK level, frequency |
| Dictionary | [CC-CEDICT](https://cc-cedict.org/wiki/) by MDBG and contributors | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | Every pinyin, meaning, measure word and traditional form in the app |
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
- Where a word has several dictionary readings, `tools/sources/readings.tsv` picks
  the everyday one. The meaning shown always comes from the CC-CEDICT entry for
  that exact reading.

## Planned sources (not used yet)

- [Tatoeba](https://tatoeba.org) example sentences (CC BY 2.0 FR), phase 2. Each
  sentence will keep its Tatoeba ID and contributor username.
- [Hanzi Writer](https://github.com/chanind/hanzi-writer) stroke order (code MIT,
  data Arphic Public License), phase 3.
