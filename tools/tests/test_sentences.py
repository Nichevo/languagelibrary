import unittest

from tools import build_data as bd
from tools import sentences as st

CEDICT = bd.parse_cedict("""\
你 你 [ni3] /you/
會 会 [hui4] /can/
說 说 [shuo1] /to speak/
說中 说中 [shuo1 zhong4] /to hit the nail on the head/
中文 中文 [Zhong1 wen2] /Chinese language/
中 中 [zhong1] /middle/
中 中 [zhong4] /to hit/
文 文 [wen2] /language/
嗎 吗 [ma5] /(question particle)/
我 我 [wo3] /I/
要 要 [yao4] /to want/
一 一 [yi1] /one/
杯 杯 [bei1] /cup/
咖啡 咖啡 [ka1 fei1] /coffee/
還 还 [hai2] /still/
還 还 [huan2] /to return/
好 好 [hao3] /good/
很 很 [hen3] /very/
""".splitlines())


def hsk(simp, *numeric):
    return {"simplified": simp, "level": ["new-1"], "forms": [{"transcriptions": {"numeric": n}} for n in numeric]}


HSK = [hsk("你", "ni3"), hsk("会", "hui4"), hsk("说", "shuo1"), hsk("中文", "Zhong1 wen2"), hsk("中", "zhong1", "zhong4"),
       hsk("吗", "ma5"), hsk("我", "wo3"), hsk("要", "yao4"), hsk("一", "yi1"), hsk("杯", "bei1"),
       hsk("咖啡", "ka1 fei1"), hsk("还", "hai2", "huan2"), hsk("好", "hao3"), hsk("很", "hen3")]


def pair(cid, zh, en, native="1"):
    return {"cmn_id": cid, "cmn": zh, "cmn_user": "a", "eng_id": "9" + cid, "eng": en, "eng_user": "b", "eng_native": native}


class Reading(unittest.TestCase):
    def setUp(self):
        self.r = st.Reader(CEDICT, [], HSK)

    def test_odd_dictionary_words_do_not_swallow_neighbours(self):
        tokens, _ = self.r.read("你会说中文吗？")
        self.assertEqual(st._pinyin_text(tokens)[0], "Nǐ huì shuō zhōng wén ma?")

    def test_two_readings_means_left_out(self):
        tokens, why = self.r.read("我还好。")
        self.assertIsNone(tokens)
        self.assertIn("more than one reading", why)

    def test_library_choice_settles_a_reading(self):
        lib = [{"id": "x", "simplified": "还", "pinyinNumbered": "hai2", "kind": "word"}]
        tokens, _ = st.Reader(CEDICT, lib, HSK).read("我还好。")
        self.assertEqual(st._pinyin_text(tokens)[0], "Wǒ hái hǎo.")

    def test_traditional_and_latin_are_left_out(self):
        self.assertIsNone(self.r.read("我要咖啡嗎？")[0])
        self.assertIsNone(self.r.read("Tom要咖啡。")[0])

    def test_yi_changes_across_words_but_third_tones_only_inside_a_word(self):
        tokens, _ = self.r.read("我要一杯咖啡。")
        p = st._pronunciation(tokens)
        self.assertEqual(p["spoken"], "Wǒ yào yì bēi kā fēi.")
        tokens, _ = self.r.read("我很好。")
        self.assertIsNone(st._pronunciation(tokens)["spoken"])  # 我 很 好 are separate words


class Phrasebook(unittest.TestCase):
    def test_entries_keep_credits_and_link_their_words(self):
        lib = [{"id": "kf", "simplified": "咖啡", "pinyinNumbered": "ka1 fei1", "kind": "word"}]
        r = st.Reader(CEDICT, lib, HSK)
        pairs = [pair("1", "我要一杯咖啡。", "I want a cup of coffee."), pair("2", "我还好。", "I'm OK.")]
        book, dropped = st.phrasebook_entries(r, pairs, [("1", "food"), ("2", "everyday"), ("3", "love")], lib)
        self.assertEqual([e["id"] for e in book], ["t1"])
        e = book[0]
        self.assertEqual(e["kind"], "sentence")
        self.assertEqual(e["meanings"], ["I want a cup of coffee."])
        self.assertEqual(e["sources"], ["Tatoeba #1 by a", "English: Tatoeba #91 by b"])
        self.assertEqual(e["related"], [{"id": "kf", "why": "Word in this sentence"}])
        self.assertEqual({d[0] for d in dropped}, {"我还好。", "Tatoeba #3"})

    def test_examples_prefer_easy_sentences(self):
        lib = [{"id": "kf", "simplified": "咖啡", "pinyinNumbered": "ka1 fei1", "kind": "word"},
               {"id": "wo", "simplified": "我", "pinyinNumbered": "wo3", "kind": "word"},
               {"id": "yao", "simplified": "要", "pinyinNumbered": "yao4", "kind": "word"}]
        r = st.Reader(CEDICT, lib, HSK)
        pairs = [pair("1", "你会说中文吗？", "Do you speak Chinese?"), pair("2", "我要咖啡。", "Coffee, please."),
                 pair("3", "我要一杯咖啡。", "I want a cup of coffee.")]
        st.add_examples(r, pairs, lib)
        self.assertEqual([x["zh"] for x in lib[0]["examples"]], ["我要咖啡。", "我要一杯咖啡。"])
        self.assertEqual(lib[0]["examples"][0]["credit"][0], "Tatoeba #2 by a")


if __name__ == "__main__":
    unittest.main()
