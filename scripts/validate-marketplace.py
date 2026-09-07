#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

NAME_RE = re.compile(r"^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$")
INSTALL_POLICIES = {"NOT_AVAILABLE", "AVAILABLE", "INSTALLED_BY_DEFAULT"}
AUTH_POLICIES = {"ON_INSTALL", "ON_USE"}


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def non_empty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate a repository-local Codex marketplace.")
    parser.add_argument("marketplace", type=Path)
    args = parser.parse_args()

    marketplace_path = args.marketplace.resolve()
    try:
        payload = json.loads(marketplace_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {marketplace_path}: {error}")

    if not isinstance(payload, dict):
        fail("marketplace root must be a JSON object")

    marketplace_name = payload.get("name")
    if not non_empty_string(marketplace_name) or NAME_RE.fullmatch(marketplace_name) is None:
        fail("marketplace name is missing or invalid")

    interface = payload.get("interface")
    if not isinstance(interface, dict) or not non_empty_string(interface.get("displayName")):
        fail("interface.displayName is required")

    entries = payload.get("plugins")
    if not isinstance(entries, list):
        fail("plugins must be an array")

    repo_root = marketplace_path.parents[2]
    catalog_names: set[str] = set()

    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            fail(f"plugins[{index}] must be an object")

        name = entry.get("name")
        if not non_empty_string(name) or NAME_RE.fullmatch(name) is None:
            fail(f"plugins[{index}].name is missing or invalid")
        if name in catalog_names:
            fail(f"duplicate marketplace entry: {name}")
        catalog_names.add(name)

        source = entry.get("source")
        expected_path = f"./plugins/{name}"
        if not isinstance(source, dict) or source.get("source") != "local":
            fail(f"{name}: source.source must be local")
        if source.get("path") != expected_path:
            fail(f"{name}: source.path must be {expected_path}")

        policy = entry.get("policy")
        if not isinstance(policy, dict):
            fail(f"{name}: policy is required")
        if policy.get("installation") not in INSTALL_POLICIES:
            fail(f"{name}: invalid policy.installation")
        if policy.get("authentication") not in AUTH_POLICIES:
            fail(f"{name}: invalid policy.authentication")
        if not non_empty_string(entry.get("category")):
            fail(f"{name}: category is required")

        plugin_dir = repo_root / "plugins" / name
        manifest_path = plugin_dir / ".codex-plugin" / "plugin.json"
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"{name}: cannot read plugin manifest: {error}")
        if not isinstance(manifest, dict) or manifest.get("name") != name:
            fail(f"{name}: folder, marketplace entry, and manifest names must match")

    plugins_dir = repo_root / "plugins"
    directory_names = {
        path.name
        for path in plugins_dir.iterdir()
        if path.is_dir() and (path / ".codex-plugin" / "plugin.json").is_file()
    }
    missing_entries = sorted(directory_names - catalog_names)
    missing_directories = sorted(catalog_names - directory_names)
    if missing_entries:
        fail(f"plugins missing from marketplace: {', '.join(missing_entries)}")
    if missing_directories:
        fail(f"marketplace entries missing plugin directories: {', '.join(missing_directories)}")

    print(f"Marketplace validation passed: {marketplace_name} ({len(entries)} plugin(s))")


if __name__ == "__main__":
    main()
