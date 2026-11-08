import unittest

from tools import generate_audio as ga

READINGS = {"他": {"ta"}, "她": {"ta"}, "好": {"hao"}, "你": {"ni"}, "一": {"yi"}, "点": {"dian"}, "行": {"xing", "hang"}}


class Judge(unittest.TestCase):
    def test_exact(self):
        self.assertEqual(ga.judge("你好", "ni3 hao3", "你好。", READINGS), "exact")

    def test_same_sound(self):
        self.assertEqual(ga.judge("她", "ta1", "他", READINGS), "sounds-same")

    def test_erhua_dropped_by_recogniser(self):
        self.assertEqual(ga.judge("一点儿", "yi1 dian3 r5", "一点", READINGS), "sounds-same")

    def test_mismatch(self):
        self.assertEqual(ga.judge("你好", "ni3 hao3", "他好", READINGS), "mismatch")
        self.assertEqual(ga.judge("你好", "ni3 hao3", "", READINGS), "mismatch")


class Request(unittest.TestCase):
    def test_request_carries_exact_pinyin(self):
        try:
            from google.cloud import texttospeech as tts
        except ImportError:
            self.skipTest("google-cloud-texttospeech not installed")

        class FakeClient:
            def synthesize_speech(self, request):
                self.request = request
                return tts.SynthesizeSpeechResponse(audio_content=b"mp3")

        client = FakeClient()
        out = ga.synthesize(tts, client, "行", "xing2", "cmn-CN-Test", tts.AudioEncoding.MP3)
        self.assertEqual(out, b"mp3")
        p = client.request.input.custom_pronunciations.pronunciations[0]
        self.assertEqual((p.phrase, p.pronunciation), ("行", "xing2"))
        self.assertEqual(p.phonetic_encoding, tts.CustomPronunciationParams.PhoneticEncoding.PHONETIC_ENCODING_PINYIN)


if __name__ == "__main__":
    unittest.main()


class RecheckTest(unittest.TestCase):
    def test_any_alternative_can_pass(self):
        self.assertEqual(ga.judge_any("你好", "ni3 hao3", ["你号", "你好"], READINGS), "exact")
        self.assertEqual(ga.judge_any("你好", "ni3 hao3", [], READINGS), "mismatch")

    def test_cedict_readings_catch_same_sounds_the_library_lacks(self):
        readings = ga.load_char_readings()
        self.assertIn("ya", readings["呀"])
        self.assertEqual(ga.judge("压", "ya1", "呀", readings), "sounds-same")
        self.assertEqual(ga.judge("搬", "ban1", "单", readings), "mismatch")

    def test_rejudge_only_ever_improves(self):
        entries = [{"id": "a", "simplified": "压", "pinyinNumbered": "ya1"},
                   {"id": "b", "simplified": "搬", "pinyinNumbered": "ban1"}]
        manifest = {"clips": {
            "a_f": {"file": "a_f.mp3", "heard": "呀", "check": "mismatch"},
            "b_f": {"file": "b_f.mp3", "heard": "单", "also": ["搬"], "check": "mismatch"},
        }}
        self.assertEqual(ga.rejudge(entries, manifest, ga.load_char_readings()), 2)
        self.assertEqual(manifest["clips"]["a_f"]["check"], "sounds-same")
        self.assertEqual(manifest["clips"]["b_f"]["check"], "exact")



class RetryTest(unittest.TestCase):
    def test_waits_out_a_brief_outage(self):
        class ServiceUnavailable(Exception):
            pass
        calls, waits = [], []

        def call():
            calls.append(1)
            if len(calls) < 3:
                raise ServiceUnavailable("503")
            return "ok"
        self.assertEqual(ga._retry(call, waits=(1, 2, 3), sleep=waits.append), "ok")
        self.assertEqual(waits, [1, 2])

    def test_other_errors_stop_at_once(self):
        def call():
            raise PermissionError("no access")
        with self.assertRaises(PermissionError):
            ga._retry(call, waits=(1,), sleep=lambda s: None)

    def test_gives_up_after_the_last_wait(self):
        class ServiceUnavailable(Exception):
            pass

        def call():
            raise ServiceUnavailable("503")
        with self.assertRaises(ServiceUnavailable):
            ga._retry(call, waits=(1, 1), sleep=lambda s: None)
