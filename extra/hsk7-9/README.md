# HSK 7 to 9 (not in the app yet)

About 5,460 advanced words (HSK 3.0 levels 7 to 9), built with:

    python -m tools.build_data --levels new-7 --words-only --out extra/hsk7-9/library.json

Their voices are made by `windows\make-voices.bat` (or
`python -m tools.generate_audio --set hsk7-9 ...`) and saved in `audio/` here,
with the same speech-recognition check as the app's clips. Nothing here is
bundled into the app. To add these words later, merge this list and its clips
into the app's library, and they appear as HSK 7 in Levels and content.
