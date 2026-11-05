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
