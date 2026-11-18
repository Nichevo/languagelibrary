import unittest

from tools import sound_pairs as sp


def entry(i, hanzi, pinyin, initial, final, tone, hsk=1, poly=False):
    return {"id": i, "simplified": hanzi, "pinyin": pinyin, "hsk": hsk, "polyphonic": poly, "frequency": 1,
            "pronunciation": {"syllables": [{"initial": initial, "final": final, "tone": tone}]}}


CLIPS = {f"{i}_{v}": {"check": "exact"} for i in "abcdefgh" for v in "fm"}


class SoundPairs(unittest.TestCase):
    def test_one_sound_apart(self):
        words = sp.candidates([entry("a", "是", "shì", "sh", "i", 4), entry("b", "四", "sì", "s", "i", 4),
                               entry("c", "十", "shí", "sh", "i", 2)], CLIPS)
        pairs = sp.build_pairs(words)
        ids = {(p["contrast"], p["a"]["ids"][0], p["b"]["ids"][0]) for p in pairs}
        self.assertIn(("hiss:sh/s", "a", "b"), ids)
        self.assertIn(("tones:2/4", "c", "a"), ids)
        self.assertNotIn("c", [p["b"]["ids"][0] for p in pairs if p["contrast"] == "hiss:sh/s"],
                         "different tone, so not a sh/s pair")

    def test_u_after_j_is_umlaut(self):
        words = sp.candidates([entry("a", "句", "jù", "j", "u", 4), entry("b", "记", "jì", "j", "i", 4)], CLIPS)
        self.assertEqual([p["contrast"] for p in sp.build_pairs(words)], ["u:ü/i"])

    def test_left_out(self):
        clips = dict(CLIPS, b_m={"check": "mismatch"})
        words = sp.candidates([entry("a", "长", "cháng", "ch", "ang", 2, poly=True), entry("b", "四", "sì", "s", "i", 4),
                               entry("c", "了", "le", "l", "e", 5), entry("d", "家", "jiā", "j", "ia", 1, hsk=None)], clips)
        self.assertEqual(words, [])

    def test_side_of(self):
        table = {"四": {"si4"}, "是": {"shi4"}, "八": {"ba1"}, "拔": {"ba2"}}
        self.assertEqual(sp.side_of("四", "shi4", "si4", "initial", table), "b")
        self.assertEqual(sp.side_of("八", "ba1", "ba2", "tone", table), "a")
        self.assertEqual(sp.side_of("", "shi4", "si4", "initial", table), "neither")
        self.assertEqual(sp.side_of("八", "shi4", "si4", "initial", table), "neither")

    def test_passes(self):
        self.assertTrue(sp.passes(97, 2, 120))
        self.assertFalse(sp.passes(89, 11, 120), "wrong too often")
        self.assertFalse(sp.passes(50, 0, 120), "decides too rarely")


if __name__ == "__main__":
    unittest.main()
