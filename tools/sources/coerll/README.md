# Chinese Dialogues Podcast transcripts

Source: [Chinese Dialogues Podcast](https://coerll.utexas.edu/coerll/oer/chinese-dialogues-podcast/)
by Wen-Hua Teng, COERLL, The University of Texas at Austin.
License: [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

- `files.tsv`: the Google Drive ids of the transcripts (PDF) and recordings (MP3).
- `epNN.txt`: each transcript's text as extracted by `pdftotext`
  (`python3 -m tools.fetch_dialogues`, normally run by the "Fetch dialogues" workflow).
  Not edited by hand.
- `checksums.tsv`: size and SHA-256 of each PDF that was read.
- `scenes.json`: draft conversation scenes from `python3 -m tools.dialogues`.
  Not used by the app until each scene has been checked in English
  (see `tools/dialogues_report.md`).
