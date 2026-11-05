import unittest

from tools import pinyin as py


class ToneMarks(unittest.TestCase):
    def test_textbook_examples(self):
        cases = {
            "ni3 hao3": "nǐ hǎo",
            "xie4 xie5": "xiè xie",
            "lu:4": "lǜ",
            "nv3 er2": "nǚ ér",
            "gou3": "gǒu",
            "liu2": "liú",
            "gui4": "guì",
            "Zhong1 guo2": "Zhōng guó",
            "yi1 dian3 r5": "yī diǎnr",
            "xue2 sheng5": "xué sheng",
        }
        for numbered, marked in cases.items():
            self.assertEqual(py.to_marks(numbered), marked, numbered)

    def test_rejects_garbage(self):
        for bad in ["ni", "hao7", "ni3hao3", "3"]:
            with self.assertRaises(ValueError):
                py.parse_numbered(bad)


class Syllables(unittest.TestCase):
    def test_valid(self):
        for s in ["ni", "hao", "zhuang", "lü", "nüe", "er", "r", "jiong", "yuan", "wo"]:
            self.assertIn(s, py.VALID_SYLLABLES, s)

    def test_invalid(self):
        for s in ["jü", "bü", "zhia", "fi", "gi", "hoa", "xa"]:
            self.assertNotIn(s, py.VALID_SYLLABLES, s)

    def test_split(self):
        self.assertEqual(py.split_initial("zhong"), ("zh", "ong"))
        self.assertEqual(py.split_initial("an"), ("", "an"))
        self.assertEqual(py.split_initial("shi"), ("sh", "i"))


def spoken(hanzi, numbered):
    return py.breakdown(hanzi, numbered)["spoken"]


class Sandhi(unittest.TestCase):
    def test_third_tone_pairs(self):
        self.assertEqual(spoken("你好", "ni3 hao3"), "ní hǎo")
        self.assertEqual(spoken("可以", "ke3 yi3"), "ké yǐ")
        self.assertEqual(spoken("水果", "shui3 guo3"), "shuí guǒ")

    def test_no_change(self):
        self.assertIsNone(spoken("谢谢", "xie4 xie5"))
        self.assertIsNone(spoken("姐姐", "jie3 jie5"))
        self.assertIsNone(spoken("中国", "Zhong1 guo2"))
        self.assertIsNone(spoken("不好", "bu4 hao3"))

    def test_bu(self):
        self.assertEqual(spoken("不是", "bu4 shi4"), "bú shì")
        self.assertEqual(spoken("不客气", "bu4 ke4 qi5"), "bú kè qi")
        self.assertIsNone(spoken("不来", "bu4 lai2"))

    def test_yi(self):
        self.assertEqual(spoken("一个", "yi1 ge4"), "yí gè")
        self.assertEqual(spoken("一起", "yi1 qi3"), "yì qǐ")
        self.assertEqual(spoken("一天", "yi1 tian1"), "yì tiān")
        self.assertEqual(spoken("一样", "yi1 yang4"), "yí yàng")

    def test_yi_unchanged(self):
        self.assertIsNone(spoken("第一", "di4 yi1"))
        self.assertIsNone(spoken("十一", "shi2 yi1"))
        self.assertIsNone(spoken("一", "yi1"))

    def test_erhua_with_sandhi(self):
        self.assertEqual(spoken("一点儿", "yi1 dian3 r5"), "yì diǎnr")

    def test_breakdown_parts(self):
        b = py.breakdown("你好", "ni3 hao3")
        self.assertEqual(b["syllables"][0]["initial"], "n")
        self.assertEqual(b["syllables"][0]["final"], "i")
        self.assertEqual(b["syllables"][0]["spokenTone"], 2)
        self.assertEqual(b["syllables"][1]["tone"], 3)
        self.assertEqual(len(b["notes"]), 1)


if __name__ == "__main__":
    unittest.main()
