#!/usr/bin/env python3
"""Download the Chinese Dialogues Podcast transcripts and keep their text.

The transcripts are PDFs in the COERLL archive on Google Drive (CC BY 3.0,
Wen-Hua Teng, The University of Texas at Austin); the file ids are listed in
tools/sources/coerll/files.tsv. Each PDF is turned into plain text with
pdftotext (poppler-utils) and saved as tools/sources/coerll/epNN.txt, so the
Chinese is copied by machine, never retyped. checksums.tsv records the size and
SHA-256 of every PDF that was read.

Google Drive is not reachable from every build machine, so this normally runs
in GitHub Actions (.github/workflows/fetch-dialogues.yml) and commits the text.

    python3 -m tools.fetch_dialogues [--from DIR]   # DIR holds already-downloaded epNN.pdf files
"""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "tools" / "sources" / "coerll"
FILES = DIR / "files.tsv"
CHECKSUMS = DIR / "checksums.tsv"
URLS = (
    "https://drive.usercontent.google.com/download?id={id}&export=download",
    "https://drive.google.com/uc?export=download&id={id}",
)


def load_files(path: Path = FILES) -> list[dict]:
    rows, head = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cells = line.split("\t")
        if head is None:
            head = cells
            continue
        rows.append(dict(zip(head, cells + [""] * (len(head) - len(cells)))))
    return rows


def download(file_id: str) -> bytes:
    last = None
    for url in URLS:
        try:
            req = urllib.request.Request(url.format(id=file_id), headers={"User-Agent": "languagelibrary-data-tools"})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            if data.startswith(b"%PDF"):
                return data
            last = f"{url.format(id=file_id)} did not return a PDF"
        except OSError as e:  # urllib errors are OSErrors
            last = f"{url.format(id=file_id)}: {e}"
    raise RuntimeError(last)


def pdf_text(pdf: bytes) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "in.pdf"
        src.write_bytes(pdf)
        out = subprocess.run(["pdftotext", "-enc", "UTF-8", str(src), "-"], check=True, capture_output=True)
    return out.stdout.decode("utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from", dest="src", type=Path, help="folder with epNN.pdf files instead of downloading")
    args = ap.parse_args(argv)
    sums = ["episode\tfile_id\tbytes\tsha256"]
    for row in load_files():
        ep, fid = row["episode"], row["transcript"]
        if not fid:
            continue
        pdf = (args.src / f"ep{ep}.pdf").read_bytes() if args.src else download(fid)
        text = pdf_text(pdf)
        if not any("一" <= c <= "鿿" for c in text):
            raise RuntimeError(f"episode {ep}: no Chinese characters in the extracted text")
        (DIR / f"ep{ep}.txt").write_text(text, encoding="utf-8")
        sums.append(f"{ep}\t{fid}\t{len(pdf)}\t{hashlib.sha256(pdf).hexdigest()}")
        print(f"episode {ep}: {len(pdf)} bytes, {len(text)} characters of text")
    CHECKSUMS.write_text("\n".join(sums) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
