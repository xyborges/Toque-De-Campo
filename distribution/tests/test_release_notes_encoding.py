"""Validate signed update notes, website history and UTF-8 for any current release."""
import copy
import html
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release_notes


def current_version():
    return json.loads(release_notes.SOURCE.read_text(encoding="utf-8"))["version"]


class ReleaseNotesEncodingTests(unittest.TestCase):
    def test_current_notes_and_site_are_legible(self):
        version = current_version()
        notes = release_notes.load_notes(version)
        self.assertEqual(notes["version"], version)
        self.assertNotIn("\ufffd", notes["summary"])
        self.assertGreaterEqual(len(notes["changes"]), 1)
        webpage = release_notes.render_download_page({
            "release_notes": notes, "version_name": version, "version": 98
        })
        self.assertIn('<meta charset="utf-8">', webpage)
        self.assertIn(html.escape(notes["title"]), webpage)
        self.assertIn(html.escape(notes["summary"]), webpage)
        self.assertIn("Histórico de atualizações", webpage)
        self.assertIn("Toque de Campo", webpage)

    def test_wrong_release_version_rejected(self):
        with self.assertRaisesRegex(ValueError, "release-notes.json"):
            release_notes.load_notes("0.0.invalid")

    def test_reject_replacement_chars_and_lost_accents(self):
        version = current_version()
        original = release_notes.load_notes(version)
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "notes.json"
            for damaged in ("A?E", "corre??es", "n?o", "visual ? dispensado", "p\ufffdgina"):
                with self.subTest(text=damaged):
                    notes = copy.deepcopy(original)
                    notes["changes"][0]["text"] = damaged
                    source.write_text(json.dumps(notes, ensure_ascii=False), encoding="utf-8")
                    with patch.object(release_notes, "SOURCE", source):
                        with self.assertRaisesRegex(ValueError, "Caracteres corrompidos"):
                            release_notes.load_notes(version)

    def test_site_rejects_damaged_history(self):
        with tempfile.TemporaryDirectory() as folder:
            fake_history = Path(folder) / "release-history.json"
            fake_history.write_text(json.dumps([{
                "version": "1.12.0", "title": "Atualiza??o",
                "additions": [], "fixes": []
            }]), encoding="utf-8")
            version = current_version()
            notes = release_notes.load_notes(version)
            with patch.object(release_notes, "HISTORY", fake_history):
                with self.assertRaisesRegex(ValueError, "Caracteres corrompidos"):
                    release_notes.render_download_page({
                        "release_notes": notes, "version_name": version, "version": 98
                    })


if __name__ == "__main__":
    unittest.main()
