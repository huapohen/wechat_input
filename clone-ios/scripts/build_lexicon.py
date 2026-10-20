#!/usr/bin/env python3
"""Build a compact SQLite lexicon for the iOS app and keyboard extension.

Reads the read-only fixtures in shared/data and writes a derived database plus
the small JSON resources consumed by the keyboard. The database is bundled into
both the app and the extension.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "shared" / "data"
OUT = Path(__file__).resolve().parents[1] / "WeTypeClone" / "Resources"
OUT.mkdir(parents=True, exist_ok=True)
DB = OUT / "lexicon.sqlite"

# A frequency prior for the candidate bar. Index = rank (lower is better).
COMMON = (
    "的一是不了人我在有他这中大来上国个到说们为子和你地出道也时年得就那要下以生会自着去之过家学对可她里后小么心多天而能好都然没日于起还发成事只作当想看文无开手十用主行方又如前所本见经头面公同三已老从动两长知民样现分将外但身些与高意进把法此实回二理美点月明其种声全工己话儿者向情部正名定女问力机给等几很业最间新什打便位因重被走电四第门相次东政海口使教西再平真听世气信北少关并内加化由却代军产入先山五太水万市眼体别处总才场师书比住员九笑性通目华报立马命张活难神数件安表原车白应路期叫死常提感金何更反合放做系计或司利受光王果亲界及今京务制解各任至清物台象记边共风战干接它许八特觉望直服毛林题建南度统色字请交爱让认算论百吃义科怎元社术结六功指思非流每青管夫连远资队跟带花快条院变联言权往展该领传近留红治决周保达办运武半候七必城父强步完革深区即求品士转量空甚众技轻程告江语英基派满式李息写呢识极令黄德收脸钱党倒未持取设始版双历越史商千片容研像找友孩站广改议形委早房音火际则首单据导影失拿网香似斯专石若兵弟谁校读志飞观争究包组造落视济喜离虽坐集编宝谈府拉黑且随格尽剑讲布杀微怕母调局根曾准团段终乐切级克精哪官示冷域抗逐吗吧呀啊喂嗯哦哈嘿唉喔呵嘛啦呗咯喽嘻咦"
)

T9 = {
    **{c: "2" for c in "abc"},
    **{c: "3" for c in "def"},
    **{c: "4" for c in "ghi"},
    **{c: "5" for c in "jkl"},
    **{c: "6" for c in "mno"},
    **{c: "7" for c in "pqrs"},
    **{c: "8" for c in "tuv"},
    **{c: "9" for c in "wxyz"},
}


def t9_digits(text: str) -> str:
    return "".join(T9.get(ch, "1") for ch in text.lower())


def load(name: str):
    with open(DATA / name, encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    chars = load("pinyin_chars.json")
    phrases = load("pinyin_phrases.json")
    wubi = load("wubi86.json")
    strokes = load("stroke_codes.json")
    english = load("english_words.json")

    if DB.exists():
        DB.unlink()
    conn = sqlite3.connect(DB)
    conn.executescript(
        """
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        CREATE TABLE chars(py TEXT, c TEXT, freq INTEGER);
        CREATE TABLE phrases(py TEXT, t9 TEXT, text TEXT, freq INTEGER);
        CREATE TABLE wubi(code TEXT, c TEXT);
        CREATE TABLE stroke(code TEXT, c TEXT);
        CREATE TABLE english(w TEXT);
        CREATE TABLE t9(digits TEXT, py TEXT);
        """
    )

    rank = {ch: i for i, ch in enumerate(COMMON)}
    char_rows = []
    for ch, py in chars.items():
        py = py.strip().lower().replace("ü", "v")
        if not py:
            continue
        char_rows.append((py, ch, rank.get(ch, 4000)))
    conn.executemany("INSERT INTO chars(py,c,freq) VALUES(?,?,?)", char_rows)

    phrase_rows = []
    for text, syllables in phrases.items():
        if not text or not syllables:
            continue
        py = "".join(str(s).strip().lower().replace("ü", "v") for s in syllables)
        phrase_rows.append((py, t9_digits(py), text, len(text)))
    conn.executemany("INSERT INTO phrases(py,t9,text,freq) VALUES(?,?,?,?)", phrase_rows)

    wubi_rows = []
    for code, items in wubi.items():
        for ch in items:
            wubi_rows.append((code.lower(), ch))
    conn.executemany("INSERT INTO wubi(code,c) VALUES(?,?)", wubi_rows)

    stroke_rows = []
    for code, items in strokes.items():
        for ch in items:
            stroke_rows.append((code.lower(), ch))
    conn.executemany("INSERT INTO stroke(code,c) VALUES(?,?)", stroke_rows)

    conn.executemany("INSERT INTO english(w) VALUES(?)", [(w.lower(),) for w in english])
    conn.executemany(
        "INSERT INTO t9(digits,py) VALUES(?,?)",
        [(t9_digits(py), py) for py in sorted({row[0] for row in char_rows})],
    )

    conn.executescript(
        """
        CREATE INDEX idx_chars_py ON chars(py);
        CREATE INDEX idx_chars_freq ON chars(freq);
        CREATE INDEX idx_phrases_py ON phrases(py);
        CREATE INDEX idx_phrases_t9 ON phrases(t9);
        CREATE INDEX idx_wubi ON wubi(code);
        CREATE INDEX idx_stroke ON stroke(code);
        CREATE INDEX idx_english ON english(w);
        CREATE INDEX idx_t9 ON t9(digits);
        """
    )
    conn.commit()
    conn.execute("VACUUM")
    conn.close()

    for name in ("emoji.json", "phrases.json", "fuzzy_pinyin.json", "double_pinyin.json"):
        (OUT / name).write_bytes((DATA / name).read_bytes())

    print(
        f"built {DB} chars={len(char_rows)} phrases={len(phrase_rows)} "
        f"wubi={len(wubi_rows)} stroke={len(stroke_rows)} english={len(english)}"
    )


if __name__ == "__main__":
    main()
