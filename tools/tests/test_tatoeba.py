import unittest

from tools import fetch_tatoeba as ft

UL = "cmn\t5\tlin\t\\N\ncmn\t3\tbob\t\\N\neng\t5\tamy\t\\N\neng\t4\tlin\t\\N\n"
CMN = (
    "1\tcmn\t你好吗？\tlin\t\\N\t\\N\n"
    "2\tcmn\t我要一杯咖啡。\tbob\t\\N\t\\N\n"  # not a native speaker
    "3\tcmn\t今天过得怎么样？\tlin\t\\N\t\\N\n"
    "4\tcmn\t这是一个非常非常非常非常非常长的句子啊。\tlin\t\\N\t\\N\n"  # too long
    "5\tcmn\t谢谢。\t\\N\t\\N\t\\N\n"  # no owner
    "6\tcmn\t没有翻译。\tlin\t\\N\t\\N\n"  # no English
)
ENG = (
    "10\teng\tHow are you?\tlin\t\\N\t\\N\n"
    "11\teng\tHow are you doing?\tamy\t\\N\t\\N\n"
    "12\teng\tI want a coffee.\tamy\t\\N\t\\N\n"
    "13\teng\tHow was your day?\tlin\t\\N\t\\N\n"
    "14\teng\tA long one.\tamy\t\\N\t\\N\n"
)
LINKS = "1\t10\n1\t11\n2\t12\n3\t13\n4\t14\n5\t10\n"


class Pick(unittest.TestCase):
    def test_native_short_translated_only(self):
        rows = ft.pick(
            ft.sentences(CMN), ft.sentences(ENG), LINKS,
            ft.native_speakers(UL, "cmn"), ft.native_speakers(UL, "eng"),
        )
        self.assertEqual([r[0] for r in rows], ["1", "3"])
        # prefers the native English translation, and keeps credits
        self.assertEqual(rows[0], ("1", "你好吗？", "lin", "11", "How are you doing?", "amy", "1"))
        self.assertEqual(rows[1][4:], ("How was your day?", "lin", "0"))

    def test_native_speakers_needs_level_5(self):
        self.assertEqual(ft.native_speakers(UL, "cmn"), {"lin"})


if __name__ == "__main__":
    unittest.main()
