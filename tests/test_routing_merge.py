import copy
import runpy
import unittest
from pathlib import Path


merge = runpy.run_path(str(Path(__file__).resolve().parents[1] / "render-client-profile.py"))["merge_routing"]


class RoutingMergeTests(unittest.TestCase):
    def setUp(self):
        self.shared = {"rules": [{"domain_keyword": ["habr", "okitty.ru"], "outbound": "Select"}]}

    def test_device_exception_precedes_shared_policy(self):
        device = {"rules": [{"domain_keyword": ["habr"], "outbound": "direct"}]}
        original = copy.deepcopy(device)
        self.assertEqual(merge(self.shared, device)["rules"], device["rules"] + self.shared["rules"])
        self.assertEqual(device, original)

    def test_preserve_additional_device_domains_and_order(self):
        device = {"rules": [{"domain_keyword": ["habr", "custom"], "outbound": "Select"}]}
        self.assertEqual(merge(self.shared, device)["rules"], device["rules"] + self.shared["rules"])

    def test_shared_changes_do_not_leave_stale_device_copies(self):
        device = {"rules": [{"domain_suffix": ["custom.test"], "outbound": "direct"}]}
        self.assertEqual(merge({}, device)["rules"], device["rules"])

    def test_device_ruleset_overrides_shared_tag(self):
        shared = {"rule_set": [{"tag": "custom", "type": "remote", "url": "https://shared.test/a.srs"}]}
        device = {"rule_set": [{"tag": "custom", "type": "remote", "url": "https://user.test/a.srs"}]}
        self.assertEqual(merge(shared, device)["rule_set"], device["rule_set"])

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
