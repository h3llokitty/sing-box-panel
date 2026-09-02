#!/usr/bin/env python3
"""Render and structurally validate a per-client sing-box profile."""

import argparse
import copy
import json
import os
import re
import sys


class RenderError(Exception):
    pass


PLACEHOLDER_RE = re.compile(r"__[A-Z0-9_]+__")


def fail(code, path, detail=""):
    suffix = f":{detail}" if detail else ""
    raise RenderError(f"{code}:{path}{suffix}")


def load_json(path, label):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail("E_JSON", label, str(exc))


def env(name, default=""):
    return os.environ.get(name, default)


def substitutions(vless_domain=""):
    try:
        allowed_ips = json.loads(env("SBP_WG_ALLOWED_IPS", "[]"))
    except json.JSONDecodeError as exc:
        fail("E_CONTEXT", "WG_ALLOWED_IPS", str(exc))
    if not isinstance(allowed_ips, list) or not all(isinstance(x, str) for x in allowed_ips):
        fail("E_CONTEXT", "WG_ALLOWED_IPS")
    try:
        typed = {
            "__WG_PORT__": int(env("SBP_WG_PORT", "0")),
            "__HY2_PORT__": int(env("SBP_HY2_PORT", "0")),
            "__VLESS_PORT__": int(env("SBP_VLESS_PORT", "0")),
            "__WG_ALLOWED_IPS__": allowed_ips,
        }
    except ValueError as exc:
        fail("E_CONTEXT", "PORT", str(exc))
    strings = {
        "__A_DOMAIN__": env("SBP_A_DOMAIN"),
        "__A_IP__": env("SBP_A_IP"),
        "__CACHE_ID__": env("SBP_CACHE_ID"),
        "__VLESS_DEST__": env("SBP_VLESS_DEST"),
        "__WG_TAG__": env("SBP_WG_TAG"),
        "__WG_ADDRESS__": env("SBP_WG_ADDRESS"),
        "__WG_PRIVATE_KEY__": env("SBP_WG_PRIVATE_KEY"),
        "__WG_PUBLIC_KEY__": env("SBP_WG_PUBLIC_KEY"),
        "__WG_PRESHARED_KEY__": env("SBP_WG_PRESHARED_KEY"),
        "__HY2_TAG__": env("SBP_HY2_TAG"),
        "__HY2_PASSWORD__": env("SBP_HY2_PASSWORD"),
        "__HY2_OBFS__": env("SBP_HY2_OBFS"),
        "__VLESS_TAG__": f"{vless_domain}_{env('SBP_PROFILE')}_vless",
        "__VLESS_DOMAIN__": vless_domain,
        "__VLESS_UUID__": env("SBP_VLESS_UUID"),
        "__REALITY_PUBLIC_KEY__": env("SBP_REALITY_PUBLIC_KEY"),
        "__REALITY_SHORT_ID__": env("SBP_REALITY_SHORT_ID"),
    }
    return {**strings, **typed}


def resolve(value, mapping, path="root"):
    if isinstance(value, dict):
        return {key: resolve(item, mapping, f"{path}.{key}") for key, item in value.items()}
    if isinstance(value, list):
        return [resolve(item, mapping, f"{path}[{index}]") for index, item in enumerate(value)]
    if not isinstance(value, str):
        return value
    if value in mapping:
        return copy.deepcopy(mapping[value])
    result = value
    for key, replacement in mapping.items():
        if key in result:
            if not isinstance(replacement, str):
                fail("E_TYPED_PLACEHOLDER", path, key)
            result = result.replace(key, replacement)
    match = PLACEHOLDER_RE.search(result)
    if match:
        fail("E_UNKNOWN_PLACEHOLDER", path, match.group(0))
    return result


def require_object(value, path):
    if not isinstance(value, dict) or not value:
        fail("E_OBJECT", path)


def require_array(value, path):
    if not isinstance(value, list):
        fail("E_ARRAY", path)
    return value


def optional_outbound(policy, key, mapping):
    """Resolve an optional standard outbound.

    Removing its key from the per-device outbounds file is the supported way
    to disable that transport for this device. A present but malformed object
    remains an error so configuration mistakes are not silently hidden.
    """
    if key not in policy or policy[key] is None:
        return None
    entry = resolve(copy.deepcopy(policy[key]), mapping)
    require_object(entry, f"outbounds.{key}")
    return entry


def validate_entries(entries, path, tags):
    for index, entry in enumerate(entries):
        item_path = f"{path}[{index}]"
        require_object(entry, item_path)
        tag = entry.get("tag")
        if not isinstance(tag, str) or not tag:
            fail("E_MISSING_TAG", item_path)
        if tag in tags:
            fail("E_DUPLICATE_TAG", item_path, tag)
        tags.add(tag)


def validate_config(config):
    require_object(config, "config")
    route = config.get("route")
    require_object(route, "route")
    rule_sets = require_array(route.get("rule_set"), "route.rule_set")
    rules = require_array(route.get("rules"), "route.rules")
    rule_set_tags = set()
    for index, item in enumerate(rule_sets):
        path = f"route.rule_set[{index}]"
        if not isinstance(item, dict):
            fail("E_OBJECT", path)
        if not isinstance(item.get("tag"), str) or not item["tag"]:
            fail("E_MISSING_TAG", path)
        if item["tag"] in rule_set_tags:
            fail("E_DUPLICATE_TAG", path, item["tag"])
        rule_set_tags.add(item["tag"])
    for index, item in enumerate(rules):
        require_object(item, f"route.rules[{index}]")

    endpoints = require_array(config.get("endpoints", []), "endpoints")
    outbounds = require_array(config.get("outbounds"), "outbounds")
    tags = set()
    validate_entries(endpoints, "endpoints", tags)
    validate_entries(outbounds, "outbounds", tags)
    final = route.get("final")
    if not isinstance(final, str) or final not in tags:
        fail("E_UNKNOWN_OUTBOUND", "route.final", str(final))
    for index, item in enumerate(rules):
        outbound = item.get("outbound")
        if outbound is not None and (not isinstance(outbound, str) or outbound not in tags):
            fail("E_UNKNOWN_OUTBOUND", f"route.rules[{index}].outbound", str(outbound))
        referenced_rule_sets = item.get("rule_set", [])
        if isinstance(referenced_rule_sets, str):
            referenced_rule_sets = [referenced_rule_sets]
        if not isinstance(referenced_rule_sets, list):
            fail("E_REFERENCE_LIST", f"route.rules[{index}].rule_set")
        for tag in referenced_rule_sets:
            if tag not in rule_set_tags:
                fail("E_UNKNOWN_RULE_SET", f"route.rules[{index}].rule_set", str(tag))
    for index, item in enumerate(outbounds):
        if item.get("type") not in ("selector", "urltest"):
            continue
        path = f"outbounds[{index}]"
        members = require_array(item.get("outbounds"), f"{path}.outbounds")
        if not members or not all(isinstance(tag, str) and tag for tag in members):
            fail("E_REFERENCE_LIST", f"{path}.outbounds")
        for tag in members:
            if tag not in tags:
                fail("E_UNKNOWN_OUTBOUND", f"{path}.outbounds", tag)
        if item.get("type") == "selector":
            default = item.get("default")
            if default not in members:
                fail("E_SELECTOR_DEFAULT", f"{path}.default", str(default))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", choices=("modern", "legacy"), required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--routing", required=True)
    parser.add_argument("--outbounds", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    base = resolve(load_json(args.template, "template"), substitutions(env("SBP_VLESS_DEST")))
    policy = load_json(args.routing, "routing")
    outbound_policy = load_json(args.outbounds, "outbounds")
    require_object(outbound_policy, "outbounds")

    rule_sets = require_array(policy.get("rule_set", []), "routing.rule_set")
    common_rules = require_array(policy.get("common_rules", []), "routing.common_rules")
    variant_rules = require_array(policy.get(f"{args.variant}_rules", []), f"routing.{args.variant}_rules")
    rules = require_array(policy.get("rules", []), "routing.rules")
    base["route"]["rule_set"].extend(copy.deepcopy(rule_sets))
    base["route"]["rules"].extend(copy.deepcopy(common_rules + variant_rules + rules))

    proxy_entries = []
    proxy_tags = []
    wg_entry = None
    mode = env("SBP_WG_PROFILE_MODE", "urltest")
    if env("SBP_WG_ENABLED") == "1" and mode != "disabled":
        wg_entry = optional_outbound(outbound_policy, "wireguard", substitutions())
        if wg_entry is not None:
            base.setdefault("endpoints", []).append(wg_entry)

    if env("SBP_HY2_ENABLED") == "1":
        entry = optional_outbound(outbound_policy, "hysteria2", substitutions())
        if entry is not None:
            proxy_entries.append(entry)
            proxy_tags.append(entry.get("tag"))

    if env("SBP_VLESS_ENABLED") == "1" and "vless" in outbound_policy and outbound_policy["vless"] is not None:
        domains = [item for item in env("SBP_VLESS_DOMAINS").splitlines() if item]
        if not domains:
            fail("E_CONTEXT", "VLESS_DOMAINS")
        for domain in domains:
            entry = optional_outbound(outbound_policy, "vless", substitutions(domain))
            proxy_entries.append(entry)
            proxy_tags.append(entry.get("tag"))

    extras = require_array(outbound_policy.get("extra_outbounds", []), "outbounds.extra_outbounds")
    variant_extras = require_array(
        outbound_policy.get(f"{args.variant}_extra_outbounds", []),
        f"outbounds.{args.variant}_extra_outbounds",
    )
    extras = resolve(copy.deepcopy(extras + variant_extras), substitutions(env("SBP_VLESS_DEST")))
    base["outbounds"].extend(proxy_entries + extras)

    auto_members = list(proxy_tags)
    if wg_entry is not None and mode == "urltest":
        auto_members.append(wg_entry["tag"])
    if auto_members:
        auto = resolve(copy.deepcopy(outbound_policy.get("urltest")), substitutions())
        require_object(auto, "outbounds.urltest")
        auto["outbounds"] = auto_members
        base["outbounds"].append(auto)

    selector = resolve(copy.deepcopy(outbound_policy.get("selector")), substitutions())
    require_object(selector, "outbounds.selector")
    selector_members = list(proxy_tags)
    if wg_entry is not None:
        selector_members.append(wg_entry["tag"])
    if auto_members:
        selector_members.append("auto")
    if not selector_members:
        fail("E_NO_CLIENT_OUTBOUND", "outbounds.selector")
    selector["outbounds"] = selector_members
    selector["default"] = "auto" if auto_members else selector_members[0]
    base["outbounds"].append(selector)

    dns_domains = base["dns"]["rules"][0].setdefault("domain", [])
    for domain in (env("SBP_A_DOMAIN"), env("SBP_VLESS_DEST")):
        if domain and domain not in dns_domains:
            dns_domains.append(domain)

    validate_config(base)
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(base, output, ensure_ascii=False, indent=2)
        output.write("\n")


if __name__ == "__main__":
    try:
        main()
    except RenderError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(2)
