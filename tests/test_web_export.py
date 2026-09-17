"""Regression tests for runtime cache reuse and complete export references."""
import gzip
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from optimize_web_export import content_address_assets, optimize_html, gzip_assets


class WebExportTests(unittest.TestCase):
    def build(self, directory, name, pack=b"game", wasm=b"wasm", worklet=b"audio"):
        config = {"executable": name, "fileSizes": {name + ".wasm": len(wasm), name + ".pck": len(pack)}}
        for suffix, data in [(".wasm", wasm), (".pck", pack), (".js", b"loader"), (".audio.worklet.js", worklet)]:
            (directory / (name + suffix)).write_bytes(data)
        html = directory / "index.html"
        html.write_text('<html lang="en"><head><style>\n\t\t</style>\n\t</head>'
                        f'<script src="{name}.js"></script>\nconst GODOT_CONFIG = {json.dumps(config, separators=(",", ":"))};\n')
        content_address_assets(directory, html)
        optimize_html(html)
        gzip_assets(directory)
        return json.loads(re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', html.read_text())[1])

    def test_runtime_reused_when_game_changes(self):
        with tempfile.TemporaryDirectory() as one, tempfile.TemporaryDirectory() as two:
            a = self.build(Path(one), "game-aaaa", b"old game")
            b = self.build(Path(two), "game-bbbb", b"new game")
            self.assertEqual(a["executable"], b["executable"])
            self.assertNotEqual(a["mainPack"], b["mainPack"])
            self.assertEqual((Path(one) / (a["executable"] + ".wasm.gz")).read_bytes(),
                             (Path(two) / (b["executable"] + ".wasm.gz")).read_bytes())

    def test_engine_change_invalidates_cache(self):
        with tempfile.TemporaryDirectory() as one, tempfile.TemporaryDirectory() as two:
            a = self.build(Path(one), "game-aaaa")
            b = self.build(Path(two), "game-bbbb", worklet=b"new audio")
            self.assertNotEqual(a["executable"], b["executable"])

    def test_references_and_gzip(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            config = self.build(directory, "game-aaaa")
            for name, size in config["fileSizes"].items():
                self.assertEqual((directory / name).stat().st_size, size)
                self.assertEqual(gzip.decompress((directory / (name + ".gz")).read_bytes()), (directory / name).read_bytes())
            html = (directory / "index.html").read_text()
            self.assertIn(f'href="{config["mainPack"]}"', html)
            self.assertNotIn("game-aaaa", html)
            content_address_assets(directory, directory / "index.html")
            self.assertEqual((directory / "index.html").read_text(), html)


if __name__ == "__main__":
    unittest.main()
