"""Regression tests: signed update manifest and website must preserve UTF-8."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release_notes


class ReleaseNotesEncodingTests(unittest.TestCase):
    def test_current_notes_and_site_are_legible(self):
        notes = release_notes.load_notes("1.13.9")
        self.assertIn("correções", notes["summary"])
        self.assertIn("árvores físicas", notes["summary"])
        self.assertIn("Inicialização", notes["changes"][3]["title"])
        html = release_notes.render_download_page({
            "release_notes": notes, "version_name": "1.13.9", "version": 97,
        })
        self.assertIn('<meta charset="utf-8">', html)
        self.assertIn("correções", html)
        self.assertIn("Polícia contra Bandidos", html)

    def test_reject_replacement_chars_and_lost_accents(self):
        original = release_notes.load_notes("1.13.9")
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "notes.json"
            for damaged in ("A?E", "corre??es", "n?o", "visual ? dispensado", "p\ufffdgina"):
                with self.subTest(text=damaged):
                    notes = copy.deepcopy(original)
                    notes["changes"][0]["text"] = damaged
                    source.write_text(json.dumps(notes, ensure_ascii=False), encoding="utf-8")
                    with patch.object(release_notes, "SOURCE", source):
                        with self.assertRaisesRegex(ValueError, "Caracteres corrompidos"):
                            release_notes.load_notes("1.13.9")

    def test_site_rejects_damaged_history(self):
        with tempfile.TemporaryDirectory() as folder:
            fake_history = Path(folder) / "release-history.json"
            fake_history.write_text(json.dumps([{
                "version": "1.12.0", "title": "Atualiza??o",
                "additions": [], "fixes": [],
            }]), encoding="utf-8")
            notes = release_notes.load_notes("1.13.9")
            with patch.object(release_notes, "HISTORY", fake_history):
                with self.assertRaisesRegex(ValueError, "Caracteres corrompidos"):
                    release_notes.render_download_page({
                        "release_notes": notes, "version_name": "1.13.9", "version": 97,
                    })


if __name__ == "__main__":
    unittest.main()
