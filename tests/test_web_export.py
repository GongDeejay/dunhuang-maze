"""Regression tests for runtime cache reuse and complete export references."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys
import subprocess
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from optimize_web_export import content_address_assets, optimize_html, gzip_assets, brotli_assets, install_intro
from verify_pack_budget import verify_pack_budget, MAX_PACK_BYTES


class WebExportTests(unittest.TestCase):
    def test_pack_budget_exact_byte_boundaries(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for size in [1, 1048576, 1048577, MAX_PACK_BYTES - 1]:
                with self.subTest(size=size):
                    (directory / "game.pck").write_bytes(b"x" * size)
                    self.assertEqual(verify_pack_budget(directory), size)
            for size in [0, MAX_PACK_BYTES, MAX_PACK_BYTES + 1]:
                with self.subTest(size=size):
                    (directory / "game.pck").write_bytes(b"x" * size)
                    with self.assertRaises(ValueError):
                        verify_pack_budget(directory)

    def test_pack_budget_rejects_missing_or_duplicate_packs(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            with self.assertRaises(ValueError):
                verify_pack_budget(directory)
            (directory / "game.pck").write_bytes(b"game")
            (directory / "old.pck").write_bytes(b"old")
            with self.assertRaises(ValueError):
                verify_pack_budget(directory)

    def build(self, directory, name, pack=b"game", wasm=b"wasm", worklet=b"audio"):
        config = {"executable": name, "fileSizes": {name + ".wasm": len(wasm), name + ".pck": len(pack)}}
        for suffix, data in [(".wasm", wasm), (".pck", pack), (".js", b"loader"), (".audio.worklet.js", worklet)]:
            (directory / (name + suffix)).write_bytes(data)
        html = directory / "index.html"
        html.write_text('<html lang="en"><head><style>\n\t\t</style>\n\t</head>'
                        f'<script src="{name}.js"></script>\nconst GODOT_CONFIG = {json.dumps(config, separators=(",", ":"))};\n')
        with html.open('a') as fixture:
            fixture.write("'onProgress': function (current, total) { statusProgress.max = total; }")
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
            self.assertIn('crossorigin fetchpriority="low"', html)
            self.assertNotIn("game-aaaa", html)
            self.assertIn('if (window.dunhuangIntro && !window.dunhuangIntro.isLoading()) return;', html)
            content_address_assets(directory, directory / "index.html")
            self.assertEqual((directory / "index.html").read_text(), html)

    def test_pinned_runtime_rejects_unplanned_upgrade(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            config = self.build(directory, "game-aaaa")
            digest = hashlib.sha256()
            for path in sorted(directory.glob(config["executable"] + ".*")):
                if path.suffix in (".wasm", ".js"):
                    digest.update(path.name[len(config["executable"]):].encode())
                    digest.update(hashlib.sha256(path.read_bytes()).digest())
            lock = {"executable": config["executable"], "sha256": digest.hexdigest()}
            content_address_assets(directory, directory / "index.html", lock)
            before = (directory / "index.html").read_bytes()
            (directory / (config["executable"] + ".wasm")).write_bytes(b"different engine")
            with self.assertRaisesRegex(ValueError, "pinned engine"):
                content_address_assets(directory, directory / "index.html", lock)
            self.assertEqual(before, (directory / "index.html").read_bytes())

    def test_intro_is_inline_and_artwork_is_lightweight(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            html = directory / "index.html"
            html.write_text('<style>\t\t</style><div id="status"><progress id="status-progress"></progress>'
                            '<div id="status-notice"></div></div><script src="engine.js"></script>'
                            '<script>statusOverlay.remove();</script>')
            install_intro(directory, html)
            result = html.read_text()
            self.assertLess(result.index('window.dunhuangIntro ='), result.index('src="engine.js"'))
            self.assertIn('window.dunhuangIntro.ready()', result)
            self.assertIn('id="intro-retry"', result)
            artwork = list(directory.glob('intro-*.webp'))
            self.assertEqual(len(artwork), 3)
            for image in artwork:
                self.assertLess(image.stat().st_size, 200000)
                self.assertIn(image.name, result)
            self.assertLess(sum(image.stat().st_size for image in artwork), 300000)
            for place in ["戈壁", "莫高窟", "三危山"]:
                self.assertIn(place, result)
            self.assertIn('id="intro-art-retry"', result)
            self.assertNotRegex(result, r'__(FAMILY|STORM|SEARCH)_IMAGE__')
            self.assertIn('data-storm-src="intro-', result)
            self.assertIn('data-search-src="intro-', result)
            for story in ['九色鹿', '三兔共耳', '建窟传说', '藏经洞', '反弹琵琶', '五台山图']:
                self.assertIn(story, result)
            self.assertIn('id="intro-show-lore"', result)
            self.assertIn('id="intro-lore-view"', result)
            entry = json.loads((Path(__file__).resolve().parents[1] / 'assets/lore/three_hares.json').read_text())
            self.assertIn(entry['teaser'], result)
            self.assertNotIn('__RABBIT_NOTE__', result)
            self.assertNotIn('__RABBIT_SVG__', result)
            self.assertIn('id="shared-ears"', result)
            self.assertIn('id="intro-rabbit-zoom"', result)
            self.assertEqual(len(re.findall(r'<svg\b', result)), 6, 'six original inline diagrams, not extra requests')
            for note in ('roadbook', 'golden_light', 'nine_deer', 'library_cave', 'pipa'):
                source_dir = 'deploy/loading/notes' if note in ('library_cave', 'pipa') else 'assets/lore'
                note_source = Path(__file__).resolve().parents[1] / source_dir
                data = json.loads((note_source / f'{note}.json').read_text())
                self.assertIn(data['teaser'], result)
                self.assertNotIn(f'__{note.upper()}_SVG__', result)
                self.assertLess((note_source / f'{note}.svg').stat().st_size, 4000)
            self.assertNotIn('__TRAVEL_NOTES__', result)
            self.assertLess((Path(__file__).resolve().parents[1] / 'assets/lore/three_hares.svg').stat().st_size, 8000)
            self.assertEqual(len(re.findall(r'<script[^>]+src=', result)), 1,
                             'lore must not introduce a remote script or library')
            self.assertLess(len(gzip.compress(result.encode())), 16000,
                            'the entire inline prologue must remain lightweight')
            install_intro(directory, html)
            self.assertEqual(result, html.read_text())

    def test_story_cache_policy_is_scoped_to_content_hash(self):
        root = Path(__file__).resolve().parents[1]
        for name in ["nginx-performance.conf", "nginx.conf.example"]:
            config = (root / "deploy" / name).read_text()
            block = re.search(r'location ~ \^/intro-.*?\n\s*}', config, re.S)[0]
            self.assertIn('[0-9a-f]+', block)
            self.assertIn('try_files $uri =404', block)
            self.assertIn('max-age=31536000, immutable', block)

    def test_brotli_roundtrip_and_stale_companion(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.build(directory, "game-aaaa", pack=b"old pack" * 100)
            brotli_assets(directory)
            for source in list(directory.glob("*.wasm")) + list(directory.glob("*.pck")):
                target = source.with_name(source.name + ".br")
                self.assertEqual(subprocess.check_output(["brotli", "-d", "-c", str(target)]), source.read_bytes())
                source.write_bytes(b"new bytes" * 100)
                brotli_assets(directory)
                self.assertEqual(subprocess.check_output(["brotli", "-d", "-c", str(target)]), source.read_bytes())


if __name__ == "__main__":
    unittest.main()
