"""Regressoes do gate de integridade sem iniciar Godot."""
from __future__ import annotations

import csv
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import run_benchmark as bench


class CollectionTests(unittest.TestCase):
    @staticmethod
    def example():
        trace = [16.0] * 625
        report = {
            "collection_protocol": bench.PROTOCOL,
            "focus": {
                "start_focused": True, "focused_frames": 625,
                "unfocused_frames": 0, "total_frames": 625,
                "transitions": 0, "change_events": [],
            },
            "bot_population": {"minimum": 28, "at_end": 28, "samples": 10},
            "measurement_window_unix_ms": {
                "start": 1_700_000_000_000, "end": 1_700_000_010_000
            },
            "frame_time_trace_ms": trace,
            "frames": {"samples": len(trace), "mean_ms": 16.0},
            "actual_vsync": 0,
            "actual_fps_cap": 0,
            "qa_presentation_only": False,
            "qa_frozen_scene": False,
            "gpu_name": "NVIDIA GeForce GTX 1650",
        }
        gpu = {
            "available": True, "matching_gpu": True,
            "window_samples": 10, "window_span_covered": True
        }
        return report, gpu, SimpleNamespace(duration=10)

    def test_valid_collection(self):
        report, gpu, args = self.example()
        self.assertTrue(bench.collection_integrity(report, args, gpu)["valid"])

    def test_lost_focus_rejects_even_with_good_fps(self):
        report, gpu, args = self.example()
        report["focus"]["focused_frames"] = 624
        report["focus"]["unfocused_frames"] = 1
        result = bench.collection_integrity(report, args, gpu)
        self.assertFalse(result["valid"])
        self.assertIn("focus_all_frames", result["failed_checks"])

    def test_focus_missing_rejects(self):
        report, gpu, args = self.example()
        report.pop("focus")
        self.assertIn("focus_all_frames",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_population_drops_reject(self):
        report, gpu, args = self.example()
        report["bot_population"]["minimum"] = 26
        self.assertIn("population_28_stable",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_gpu_gap_reject(self):
        report, gpu, args = self.example()
        gpu["window_span_covered"] = False
        self.assertIn("gpu_window_synchronized",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_competing_godot_preflight_detection(self):
        windows_tasklist = (
            '"Godot_v4.7.2-stable_win64.exe","1234","Console","1","100 K"\\n'
            '"chrome.exe","4321","Console","1","100 K"'
        )
        with patch.object(bench.os, "name", "nt"):
            with patch.object(bench, "command_output", return_value=windows_tasklist):
                processes = bench.competing_godot_processes()
        self.assertEqual(processes, [{"image": "Godot_v4.7.2-stable_win64.exe",
                                      "pid": "1234"}])

    def test_missing_gpu_window_reject(self):
        report, gpu, args = self.example()
        gpu["window_samples"] = 2
        self.assertIn("gpu_window_synchronized",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_bad_timestamps_reject(self):
        report, gpu, args = self.example()
        report["measurement_window_unix_ms"]["end"] -= 5000
        self.assertIn("full_window",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_tampered_frame_trace_reject(self):
        report, gpu, args = self.example()
        report["frame_time_trace_ms"][0] = 50.0
        self.assertIn("raw_frames_complete",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_probe_only_reject(self):
        report, gpu, args = self.example()
        report["qa_presentation_only"] = True
        self.assertIn("real_simulation",
                      bench.collection_integrity(report, args, gpu)["failed_checks"])

    def test_selects_only_matching_gpu_within_window(self):
        report, _, _ = self.example()
        with TemporaryDirectory() as tmp:
            original = Path(tmp) / "all.csv"
            selected = Path(tmp) / "measurement.csv"
            with original.open("w", newline="", encoding="utf-8") as file:
                writer = csv.DictWriter(file, fieldnames=bench.GPU_CSV_FIELDS)
                writer.writeheader()
                for timestamp, name in [
                    (1_699_999_999_000, "NVIDIA GeForce GTX 1650"),
                    (1_700_000_000_500, "NVIDIA GeForce GTX 1650"),
                    (1_700_000_002_000, "Different GPU"),
                    (1_700_000_009_800, "NVIDIA GeForce GTX 1650"),
                    (1_700_000_011_000, "NVIDIA GeForce GTX 1650")
                ]:
                    writer.writerow({
                        "sample_unix_ms": timestamp, "query_duration_ms": 10,
                        "gpu_index": 0, "name": name,
                        "temperature.gpu": "65", "utilization.gpu": "50 %",
                        "clocks.sm": "1200 MHz", "power.draw": "50 W",
                        "pstate": "P0"
                    })
            outcome = bench.select_gpu_measurement_rows(original, selected, report)
            self.assertTrue(outcome["matching_gpu"])
            self.assertEqual(outcome["total_samples"], 5)
            self.assertEqual(outcome["window_samples"], 2)
            with selected.open(encoding="utf-8", newline="") as file:
                self.assertEqual(len(list(csv.DictReader(file))), 2)


if __name__ == "__main__":
    unittest.main()
