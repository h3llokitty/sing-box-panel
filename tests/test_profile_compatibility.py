import copy
import re
import runpy
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
renderer = runpy.run_path(str(ROOT / "render-client-profile.py"))


class HttpClientMigrationTests(unittest.TestCase):
    def test_preserve_download_routes_and_existing_clients(self):
        config = {"outbounds": [{"type": "direct", "tag": "direct"}], "route": {"final": "Select", "rule_set": [
            {"type": "remote", "tag": "a", "download_detour": "direct"},
            {"type": "remote", "tag": "b", "download_detour": "Select"},
            {"type": "remote", "tag": "c"},
            {"type": "remote", "tag": "d", "http_client": {"detour": "direct", "headers": {"X-Test": "1"}}},
            {"type": "local", "tag": "e", "path": "rules.srs"},
        ]}}
        original = copy.deepcopy(config)
        renderer["migrate_rule_set_http_clients"](config)
        rules = config["route"]["rule_set"]
        self.assertEqual(rules[0]["http_client"], "ruleset-direct")
        self.assertEqual([r["http_client"]["detour"] for r in rules[1:3]], ["Select", "Select"])
        clients = {client["tag"]: client for client in config["http_clients"]}
        self.assertEqual(clients["ruleset-direct"], {"tag": "ruleset-direct"})
        self.assertEqual(clients[rules[3]["http_client"]]["headers"], {"X-Test": "1"})
        self.assertNotIn("detour", clients[rules[3]["http_client"]])
        self.assertTrue(all("download_detour" not in r for r in rules))
        self.assertEqual(rules[4:], original["route"]["rule_set"][4:])

    def test_reuses_named_direct_client_without_tag_collision(self):
        config = {"outbounds": [{"type": "direct", "tag": "direct"}],
                  "http_clients": [{"tag": "ruleset-direct", "detour": "Select"}],
                  "route": {"final": "Select", "rule_set": [
                      {"type": "remote", "tag": tag, "download_detour": "direct"} for tag in ("a", "b")
                  ]}}
        renderer["migrate_rule_set_http_clients"](config)
        self.assertEqual([r["http_client"] for r in config["route"]["rule_set"]], ["ruleset-direct-2"] * 2)
        self.assertEqual(len(config["http_clients"]), 2)

    def test_preserves_configured_direct_outbound(self):
        config = {"outbounds": [{"type": "direct", "tag": "bound", "bind_interface": "eth0"}],
                  "route": {"final": "Select", "rule_set": [
                      {"type": "remote", "tag": "a", "download_detour": "bound"}
                  ]}}
        renderer["migrate_rule_set_http_clients"](config)
        self.assertEqual(config["route"]["rule_set"][0]["http_client"], {"detour": "bound"})

    def test_reject_ambiguous_download_route(self):
        config = {"route": {"final": "Select", "rule_set": [
            {"type": "remote", "tag": "a", "download_detour": "direct", "http_client": {"detour": "Select"}}
        ]}}
        with self.assertRaises(renderer["RenderError"]):
            renderer["migrate_rule_set_http_clients"](config)


class UserAgentSelectionTests(unittest.TestCase):
    def test_client_version_boundaries(self):
        entries = []
        text = (ROOT / "templates/singbox-ua.conf").read_text()
        for pattern, variant in re.findall(r'"~\*([^"\n]+)"\s+"(legacy|modern14)";', text):
            entries.append((re.compile(pattern, re.I), variant))
        self.assertEqual(len(entries), 2)
        cases = {
            "sing-box/1.9.0": "legacy", "sing-box/1.11.15": "legacy",
            "sing-box/1.12.0": "modern", "sing-box/1.13.9": "modern",
            "SFA (sing-box 1.14.4; language en_RU)": "modern14",
            "Speed Bunny/1.15.1 (Build 1; sing-box 1.14.0-beta.5; language en_KZ)": "modern14",
            "sing-box/1.14": "modern14", "sing-box/1.16.0": "modern14",
            "sing-box/1.100.0": "modern14", "sing-box/2.0.0": "modern14",
            "sing-box/10.0.0": "modern14", "Mozilla/5.0": "modern",
        }
        for ua, expected in cases.items():
            with self.subTest(ua=ua):
                actual = next((variant for pattern, variant in entries if pattern.search(ua)), "modern")
                self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
