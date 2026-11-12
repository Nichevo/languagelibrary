#!/usr/bin/env python3
"""Download the full license texts that ship inside the app (app/assets/licenses/)."""

import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "licenses"
FILES = {
    "CC-BY-SA-4.0.txt": "https://raw.githubusercontent.com/spdx/license-list-data/main/text/CC-BY-SA-4.0.txt",
    "complete-hsk-vocabulary-MIT.txt": "https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/LICENSE",
    "Apache-2.0.txt": "https://www.apache.org/licenses/LICENSE-2.0.txt",
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, url in FILES.items():
        with urllib.request.urlopen(url, timeout=60) as r:
            (OUT / name).write_bytes(r.read())
        print(f"saved {name}")


if __name__ == "__main__":
    main()
