import copy
import runpy
import unittest
from pathlib import Path


merge = runpy.run_path(str(Path(__file__).resolve().parents[1] / "render-client-profile.py"))["merge_routing"]


class RoutingMergeTests(unittest.TestCase):
    def setUp(self):
        self.shared = {"rules": [{"domain_keyword": ["habr", "okitty.ru"], "outbound": "Select"}]}

    def test_old_device_snapshot_is_covered(self):
        device = {"rules": [{"domain_keyword": ["habr"], "outbound": "Select"}]}
        original = copy.deepcopy(device)
        self.assertEqual(merge(self.shared, device)["rules"], self.shared["rules"])
        self.assertEqual(device, original)

    def test_preserve_additional_device_domains_and_order(self):
        device = {"rules": [{"domain_keyword": ["habr", "custom"], "outbound": "Select"}]}
        self.assertEqual(merge(self.shared, device)["rules"], self.shared["rules"] + device["rules"])

    def test_preserve_different_outbound(self):
        device = {"rules": [{"domain_keyword": ["habr"], "outbound": "direct"}]}
        self.assertEqual(len(merge(self.shared, device)["rules"]), 2)

    def test_preserve_compound_and_inverted_rules(self):
        for extra in ({"invert": True}, {"port": [443]}):
            device = {"rules": [{"domain_keyword": ["habr"], "outbound": "Select", **extra}]}
            self.assertEqual(len(merge(self.shared, device)["rules"]), 2)

    def test_inheritance_opt_out(self):
        device = {"inherit_global": False, "rules": [{"domain_keyword": ["habr"], "outbound": "direct"}]}
        self.assertEqual(merge(self.shared, device), device)

    def test_new_devices_and_exact_duplicates(self):
        self.assertEqual(merge(self.shared, {})["rules"], self.shared["rules"])
        self.assertEqual(merge(self.shared, self.shared)["rules"], self.shared["rules"])


if __name__ == "__main__":
    unittest.main()
