import unittest

from tools import build_data as bd

CEDICT = """\
# test data
你好 你好 [ni3 hao3] /hello; hi/
個 个 [ge4] /(classifier used before a noun that has no specific classifier)/
書 书 [shu1] /book/CL:本[ben3]/
還 还 [hai2] /still/yet/
還 还 [huan2] /to return/
還 还 [Huan2] /surname Huan/
一點 一点 [yi1 dian3] /a bit/
一點兒 一点儿 [yi1 dian3 r5] /erhua variant of 一點|一点[yi1 dian3]/
行 行 [xing2] /to walk/OK/
行 行 [hang2] /row/
""".splitlines()


def hsk_word(simp, *numeric):
    return {
        "simplified": simp,
        "level": ["new-1"],
        "frequency": 1,
        "forms": [{"transcriptions": {"numeric": n}, "meanings": ["x"]} for n in numeric],
    }


class Build(unittest.TestCase):
    def run_build(self, hsk, phrases=()):
        return bd.build(bd.parse_cedict(CEDICT), hsk, list(phrases), ["new-1"])

    def test_keeps_agreeing_word_with_cedict_meaning_and_classifier(self):
        entries, dropped, _ = self.run_build([hsk_word("书", "shu1")])
        self.assertEqual(dropped, [])
        e = entries[0]
        self.assertEqual(e["pinyin"], "shū")
        self.assertEqual(e["meanings"], ["book"])  # from CC-CEDICT, not the HSK list
        self.assertEqual(e["classifiers"], [{"hanzi": "本", "pinyin": "běn"}])

    def test_drops_when_pinyin_disagrees(self):
        entries, dropped, _ = self.run_build([hsk_word("书", "shu4")])
        self.assertEqual(entries, [])
        self.assertIn("does not agree", dropped[0][1])

    def test_drops_fake_syllable(self):
        entries, dropped, _ = self.run_build([hsk_word("书", "shia1")])
        self.assertEqual(entries, [])
        self.assertIn("not real Mandarin", dropped[0][1])

    def test_chosen_readings_become_separate_entries(self):
        entries, dropped, _ = self.run_build([hsk_word("还", "Huan2", "hai2", "huan2")])
        self.assertEqual(dropped, [])
        self.assertEqual({e["pinyin"] for e in entries}, {"hái", "huán"})
        meanings = {e["pinyin"]: e["meanings"] for e in entries}
        self.assertEqual(meanings["huán"], ["to return"])

    def test_erhua_borrows_base_meaning(self):
        entries, _, _ = self.run_build([hsk_word("一点儿", "yi1 dian3 r5")])
        self.assertEqual(entries[0]["meanings"], ["a bit"])
        self.assertEqual(entries[0]["pinyin"], "yī diǎnr")
        self.assertTrue(entries[0]["notes"])

    def test_polyphonic_flag(self):
        entries, _, flagged = self.run_build([hsk_word("行", "xing2", "hang2")])
        self.assertTrue(all(e["polyphonic"] for e in entries))
        self.assertTrue(flagged)

    def test_phrase_must_exist_in_cedict(self):
        entries, dropped, _ = self.run_build([], [("你好", "ni3 hao3", "everyday"), ("我爱你", "wo3 ai4 ni3", "family")])
        self.assertEqual([e["simplified"] for e in entries], ["你好"])
        self.assertEqual(dropped[0][0], "我爱你")


if __name__ == "__main__":
    unittest.main()
