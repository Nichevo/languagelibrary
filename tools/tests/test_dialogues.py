import unittest

from tools import build_data as bd
from tools import dialogues as dg
from tools import sentences as st
from tools.fetch_dialogues import load_files

CEDICT = bd.parse_cedict("""\
你 你 [ni3] /you/
好 好 [hao3] /good/
嗎 吗 [ma5] /(question particle)/
我 我 [wo3] /I/
很 很 [hen3] /very/
忙 忙 [mang2] /busy/
不 不 [bu4] /not/
姓 姓 [xing4] /surname/
謝 谢 [xie4] /to thank/
謝謝 谢谢 [xie4 xie5] /thanks/
呢 呢 [ne5] /particle/
他們 他们 [ta1 men5] /they/
都 都 [dou1] /all/
請問 请问 [qing3 wen4] /excuse me/
貴姓 贵姓 [gui4 xing4] /your surname?/
""".splitlines())


def hsk(simp, numeric, level="new-1"):
    return {"simplified": simp, "level": [level], "forms": [{"transcriptions": {"numeric": numeric}}]}


HSK = [hsk("你", "ni3"), hsk("好", "hao3"), hsk("吗", "ma5"), hsk("我", "wo3"), hsk("很", "hen3"), hsk("忙", "mang2"),
       hsk("不", "bu4"), hsk("姓", "xing4", "new-2"), hsk("谢谢", "xie4 xie5"), hsk("呢", "ne5"),
       hsk("他们", "ta1 men5"), hsk("都", "dou1"), hsk("请问", "qing3 wen4", "new-2"), hsk("贵姓", "gui4 xing4", "new-3")]

TEXT = """Chinese Podcast Episode #1 (Simplified Characters)

Dialogue #2

A: 你好吗？

B: 我很好。

A: 你忙吗？（or 你忙不忙？）

B: 我不忙。

Dialogue #6

A: 请问你贵姓？

B: 我姓谢，你呢？

Dialogue #9

A: 你忙吗？

B: 我（很）忙。

A: Ah! 你

很忙。

Chinese Podcast Episode #1 (Traditional Characters)

Dialogue #2

A: 你好嗎？

B: 我很好。

A: 你忙嗎？（or 你忙不忙？）

B: 我不忙。

Dialogue #6

A: 請問你貴姓？

B: 我姓謝，你呢？

Dialogue #9

A: 你忙嗎？

B: 我（很）忙。

A: Ah! 你很忙。

Chinese Podcast Episode #1 (English Translations)

Dialogue #2

A: How are you? B: I am fine. A: Are you busy?
B: I am not busy.

Dialogue #6

(At a party)

A: May I ask your last name? B: My last name is Xie. How about you?

Dialogue #9

Mr. Wang: Are you busy? New employee: I am (very) busy. Mr. Wang: Ah! You are busy.
"""


class ParseTest(unittest.TestCase):
    def setUp(self):
        self.ds = dg.parse_episode("01", TEXT)

    def test_dialogues_and_lines(self):
        self.assertEqual([d["num"] for d in self.ds], [2, 6, 9])
        d2 = self.ds[0]
        self.assertEqual([ln["raw"] for ln in d2["lines"]], ["你好吗？", "我很好。", "你忙吗？（or 你忙不忙？）", "我不忙。"])
        self.assertEqual(d2["lines"][2]["en"], "Are you busy?")
        self.assertEqual(d2["problems"], [])

    def test_wrapped_line_and_english_labels(self):
        d9 = self.ds[2]
        self.assertEqual(d9["lines"][2]["raw"], "Ah! 你很忙。")
        self.assertEqual([ln["en"] for ln in d9["lines"]], ["Are you busy?", "I am (very) busy.", "Ah! You are busy."])
        self.assertEqual(self.ds[1]["note"], "At a party")

    def test_variants(self):
        self.assertEqual(dg.variants("你忙吗？（or 你忙不忙？）"), ("你忙吗？", ["你忙不忙？"]))
        self.assertEqual(dg.variants("我（很）忙。"), ("我很忙。", ["我忙。"]))
        self.assertEqual(dg.variants("你妈妈在国外 (or 外国)。"), ("你妈妈在国外。", []))


class CheckTest(unittest.TestCase):
    def setUp(self):
        self.ds = dg.parse_episode("01", TEXT)
        reader = st.Reader(CEDICT, [], HSK)
        dg.check_all(self.ds, reader, dg.trad_to_simp(CEDICT), dg.word_levels([], HSK))
        self.lines = {ln["id"]: ln for d in self.ds for ln in d["lines"]}

    def test_checks(self):
        self.assertTrue(self.lines["d2.1"]["ok"])
        self.assertEqual(self.lines["d2.1"]["pinyin"], "Nǐ hǎo ma?")
        self.assertEqual(self.lines["d2.3"]["alts"][0]["zh"], "你忙不忙？")
        self.assertFalse(self.lines["d9.3"]["ok"])
        self.assertIn("English", self.lines["d9.3"]["why"])
        self.assertEqual(self.lines["d6.1"]["hsk"], 3)

    def test_scripts_must_agree(self):
        t2s = dg.trad_to_simp(CEDICT)
        self.assertEqual(dg.scripts_agree("你好吗？", "你好嗎？", t2s), "")
        self.assertIn("differ", dg.scripts_agree("他们的车", "他們的美國車", t2s))

    def test_web(self):
        turns = dg.build_web(self.ds)
        # 你忙吗 is asked in dialogues 2 and 9, so each answer is a right reply for the other.
        t = turns["d2.4"]
        self.assertEqual([r["zh"] for r in t["right"]], ["我不忙。", "我很忙。"])
        self.assertEqual(t["right"][1]["line"], "d9.2")
        self.assertIsNotNone(t["wrong"])
        self.assertNotIn(self.lines[t["wrong"]]["zh"], {"我不忙。", "我很忙。"})
        out = dg.build_output(self.ds, turns)
        # 谢 on its own is only a family name here, so 我姓谢 can't be checked and dialogue 6 has one usable line.
        self.assertEqual([s["id"] for s in out["scenes"]], ["d2", "d9"])
        self.assertEqual(out["scenes"][1]["lines"], ["d9.1", "d9.2"])

    def test_prompt_key(self):
        self.assertEqual(dg.prompt_key("请问你贵姓？"), dg.prompt_key("你贵姓?"))


class FilesTest(unittest.TestCase):
    def test_file_list(self):
        rows = load_files()
        self.assertEqual(len(rows), 21)
        self.assertEqual(sum(1 for r in rows if r["transcript"]), 20)


if __name__ == "__main__":
    unittest.main()
