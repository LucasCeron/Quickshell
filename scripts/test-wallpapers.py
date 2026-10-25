#!/usr/bin/env python3
"""Regression checks for wallpaper discovery and Hyprpaper acknowledgements."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("wallpapers", Path(__file__).with_name("wallpapers.py"))
wallpapers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpapers)


class WallpapersTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.image = self.root / "Paisagem com espaços.png"
        self.image.touch()

    def apply_with_reply(self, reply="", code=0):
        monitors = subprocess.CompletedProcess([], 0, '[{"name":"HDMI-A-1"}]', "")
        result = subprocess.CompletedProcess([], code, reply, "")
        with patch.object(wallpapers.subprocess, "run", side_effect=[monitors, result]) as run:
            value = wallpapers.apply(str(self.image))
            self.assertEqual(run.call_args.args[0][-1], f"HDMI-A-1,{self.image},cover")
            return value

    def test_empty_success_reply(self):
        self.assertEqual(self.apply_with_reply(), str(self.image))

    def test_legacy_ok_reply(self):
        self.assertEqual(self.apply_with_reply("ok\n"), str(self.image))

    def test_error_reply_even_with_zero_exit(self):
        with self.assertRaises(ValueError):
            self.apply_with_reply("error: invalid monitor")

    def test_nonzero_exit_with_empty_reply(self):
        with self.assertRaises(ValueError):
            self.apply_with_reply(code=1)

    def test_missing_image_never_calls_ipc(self):
        with patch.object(wallpapers.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                wallpapers.apply(str(self.root / "missing.png"))
            run.assert_not_called()

    def test_scan_deduplicates_and_skips_hidden_directories(self):
        (self.root / "alias.png").symlink_to(self.image)
        hidden = self.root / ".hidden"
        hidden.mkdir()
        (hidden / "hidden.png").touch()
        (self.root / "notes.txt").touch()
        items = wallpapers.scan(str(self.root))
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["path"], str(self.image))
        self.assertIn("%20", items[0]["url"])

    def test_missing_folder_reports_error(self):
        with self.assertRaises(ValueError):
            wallpapers.scan(str(self.root / "missing"))


if __name__ == "__main__":
    unittest.main()
