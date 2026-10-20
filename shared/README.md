# Shared specifications and data

This directory is the single source of truth for the three reconstructions.

| Path | Contents | Source |
|---|---|---|
| `spec/design_tokens.json` | colors, spacing, typography, radii, grid | sampled from the original runtime screenshots and rebuilt |
| `spec/keyboard_layouts.json` | 36 keyboard geometries, key labels, T9 flags | facts extracted from the APK's `assets/keyboard/output/*.json` |
| `spec/keyboard_modes.json` | ten user-facing modes and their layout files | original mode list + APK layouts |
| `spec/pages.json` | page inventory and routes | REA module registry + runtime pages |
| `data/pinyin_chars.json` | 26,703 characters → toneless pinyin | pypinyin (MIT), generated |
| `data/pinyin_phrases.json` | 46,111 words → syllables | pypinyin phrase dictionary |
| `data/wubi86.json` | 26,271 Wubi 86 codes → candidates | Rime `wubi86` dictionary |
| `data/stroke_codes.json` | 5,064 five-stroke codes → candidates | Rime `stroke` dictionary |
| `data/double_pinyin.json` | 小鹤 / 自然码 / 微软 key maps | rebuilt common mappings |
| `data/fuzzy_pinyin.json` | fuzzy pairs | APK `FuzzyPinyinInfo` fields |
| `data/emoji.json` | categorized emoji | curated, Unicode characters |
| `data/phrases.json` | starter phrases | curated |
| `data/english_words.json` | starter English lexicon | curated common words |

## Attribution

- **pypinyin** — MIT, https://github.com/mozillazg/python-pinyin
- **Rime wubi86** — Rime dictionary, see `sources/wubi86.dict.yaml` header and
  https://github.com/rime/rime-wubi
- **Rime stroke** — Rime dictionary, see `sources/stroke.dict.yaml` header and
  https://github.com/rime/rime-stroke

The clone does **not** ship Tencent APK binaries, Hermes bundles, proprietary
dictionaries, fonts or drawable assets. Keyboard geometry and UI structure are
facts used for interoperability; the visual implementation is rebuilt.

This is an independent study clone and is not affiliated with Tencent.
