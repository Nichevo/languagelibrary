import unittest

from tools import char_tones as ct


def cedict(simplified: str, pinyin: str) -> dict:
    return {"simplified": simplified, "traditional": simplified, "pinyin": pinyin, "glosses": [], "classifiers": []}


class CharTones(unittest.TestCase):
    def test_single_characters_keep_their_tones(self):
        table = ct.char_tones([cedict("买", "mai3"), cedict("卖", "mai4"), cedict("了", "le5"), cedict("了", "liao3")])
        self.assertEqual(table["买"], {"mai3"})
        self.assertEqual(table["卖"], {"mai4"})
        self.assertEqual(table["了"], {"le5", "liao3"})

    def test_words_only_fill_characters_without_an_entry(self):
        table = ct.char_tones([cedict("见", "jian4"), cedict("看见", "kan4 jian5"), cedict("琵琶", "pi2 pa5")])
        self.assertEqual(table["见"], {"jian4"}, "a neutral tone inside a word is not a reading of its own")
        self.assertEqual(table["看"], {"kan4"})
        self.assertEqual(table["琵"], {"pi2"})
        self.assertNotIn("琶", table)

    def test_library_readings_are_added(self):
        table = ct.char_tones([cedict("谢", "xie4")], [{"simplified": "谢谢", "pinyinNumbered": "xie4 xie5"}])
        self.assertEqual(table["谢"], {"xie4", "xie5"})

    def test_skips_mismatched_and_non_chinese(self):
        table = ct.char_tones([cedict("AA制", "A A zhi4"), cedict("女", "nu:3"), cedict("一点儿", "yi1 dian3")])
        self.assertEqual(table, {"制": {"zhi4"}, "女": {"nü3"}})


if __name__ == "__main__":
    unittest.main()
