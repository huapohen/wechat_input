# Dictionary sources

## pypinyin

- Project: https://github.com/mozillazg/python-pinyin
- License: MIT
- Used to generate `data/pinyin_chars.json`, `data/pinyin_phrases.json`,
  `data/pinyin_syllables.json`. The generated files are derived data.

## Rime wubi86

- Project: https://github.com/rime/rime-wubi
- File: `wubi86.dict.yaml` (kept verbatim)
- Used to generate `data/wubi86.json` and `data/wubi_char_codes.json`.
- See the file header for authors and changelog.

## Rime stroke

- Project: https://github.com/rime/rime-stroke
- File: `stroke.dict.yaml` (kept verbatim)
- Used to generate `data/stroke_codes.json` and
  `data/stroke_char_codes.json`.
- See the file header for the CNS 11643 provenance and authors.

## Original APK

The keyboard layout *facts* (row/column geometry, key labels, T9 flag) were
extracted from `com.tencent.wetype` 4.0.0 for interoperability analysis. No
Tencent asset, font, dictionary or code is included in this repository.
