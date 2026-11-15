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


class RemakeTest(unittest.TestCase):
    ENTRIES = [{"id": "dui", "simplified": "对", "pinyin": "duì", "pinyinNumbered": "dui4"},
               {"id": "ni", "simplified": "你", "pinyin": "nǐ", "pinyinNumbered": "ni3"}]

    def _list(self, text):
        import tempfile
        from pathlib import Path
        d = tempfile.mkdtemp()
        p = Path(d) / "remake_clips.tsv"
        p.write_text(text, encoding="utf-8")
        return p

    def test_reads_the_list(self):
        p = self._list("# note\n对\tduì\tfemale\t1\tcut short\n好\thǎo\tmale\t1\n")
        self.assertEqual(ga.load_remake_list(self.ENTRIES, p), [("dui_f", 1, "对")])

    def test_only_newer_takes_are_due(self):
        p = self._list("对\tduì\tfemale\t2\n你\tnǐ\tmale\t1\n")
        orig = ga.REMAKE_LIST
        ga.REMAKE_LIST = p
        try:
            manifest = {"clips": {"dui_f": {"take": 1}, "ni_m": {"take": 1}}}
            self.assertEqual(ga.remakes_due(self.ENTRIES, manifest), [("dui_f", 2, "对")])
        finally:
            ga.REMAKE_LIST = orig

    def test_voiced_ms_counts_a_steady_voice(self):
        import io
        import math
        import struct
        import wave
        rate = 24000
        tone = [int(8000 * math.sin(2 * math.pi * 200 * i / rate)) for i in range(int(rate * 0.3))]
        silence = [0] * int(rate * 0.2)
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(struct.pack(f"<{len(tone) + 2 * len(silence)}h", *silence, *tone, *silence))
        try:
            ms = ga.voiced_ms(buf.getvalue())
        except ImportError:
            self.skipTest("numpy not installed")
        self.assertGreater(ms, 200)
        self.assertLess(ms, 360)

    def test_keeps_the_confirmed_take_with_the_most_voice(self):
        import json
        import tempfile
        from pathlib import Path
        from types import SimpleNamespace
        d = Path(tempfile.mkdtemp())
        (d / "manifest.json").write_text(json.dumps({"voices": {}, "clips": {
            "dui_f": {"file": "dui_f.mp3", "bytes": 3, "heard": "对", "check": "exact"}}}), encoding="utf-8")
        p = self._list("对\tduì\tfemale\t1\n")
        takes = {("对。", 1.0): ("对", 300), ("对", 0.9): ("对", 450), ("对。", 0.9): ("退", 600)}
        saved = {k: getattr(ga, k) for k in ("REMAKE_LIST", "AUDIO_DIR", "MANIFEST", "REPORT", "synthesize",
                                             "transcribe", "voiced_ms", "write_report")}
        made = []

        def synth(tts_mod, client, text, numbered, voice, encoding, rate=1.0):
            self.assertEqual(numbered, "dui4")
            if encoding == "mp3":
                made.append((text, rate))
                return b"new-mp3"
            return (text, rate)
        ga.REMAKE_LIST, ga.AUDIO_DIR, ga.MANIFEST, ga.REPORT = p, d, d / "manifest.json", d / "report.md"
        ga.synthesize = synth
        ga.transcribe = lambda speech_mod, client, wav: [takes[wav][0]]
        ga.voiced_ms = lambda wav: takes[wav][1]
        ga.write_report = lambda entries, manifest: None
        fake = SimpleNamespace(TextToSpeechClient=lambda: None, AudioEncoding=SimpleNamespace(LINEAR16="wav", MP3="mp3"))
        fake_stt = SimpleNamespace(SpeechClient=lambda: None)
        try:
            ga.cmd_remake(fake, fake_stt, self.ENTRIES, "F", "M")
        finally:
            for k, v in saved.items():
                setattr(ga, k, v)
        self.assertEqual(made, [("对", 0.9)])  # 退 was voiced longest but is the wrong word
        self.assertEqual((d / "dui_f.mp3").read_bytes(), b"new-mp3")
        clip = json.loads((d / "manifest.json").read_text(encoding="utf-8"))["clips"]["dui_f"]
        self.assertEqual((clip["take"], clip["bytes"], clip["check"]), (1, 7, "exact"))
