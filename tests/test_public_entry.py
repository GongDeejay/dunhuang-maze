import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("check_public_entry", Path(__file__).parents[1] / "tools/check_public_entry.py")
entry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)


class PublicEntryTests(unittest.TestCase):
    def test_redirect_must_stay_on_https_same_host(self):
        for location, valid in [("https://maze.mplusm.site:8443/", True), ("http://maze.mplusm.site:8443/", False), ("https://example.com/", False)]:
            self.assertEqual(entry.acceptable("http", {"status": 301, "headers": {"location": location}}, "maze.mplusm.site"), valid)

    def test_https_needs_real_game_isolation_headers(self):
        self.assertFalse(entry.acceptable("https", {"status": 200, "headers": {}}, "maze.mplusm.site"))
        self.assertTrue(entry.acceptable("https", {"status": 200, "headers": {"cross-origin-opener-policy": "same-origin", "cross-origin-embedder-policy": "require-corp"}}, "maze.mplusm.site"))

    def test_connection_error_cannot_be_hidden_by_success_on_another_port(self):
        self.assertFalse(entry.acceptable("https", {"error": "Connection reset by peer"}, "maze.mplusm.site"))
