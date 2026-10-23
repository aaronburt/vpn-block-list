"""Write the manifest that the GitHub Pages command generator reads."""

import argparse
import hashlib
import json
import os
import re
import subprocess

IMPORT_SCRIPT = "crowdsec/docker_crowdsec_ban_import.sh"
# Least to most collateral damage; unknown categories sort after these.
CATEGORY_ORDER = ["vpn", "vpn-infrastructure", "hosting"]


def slug(text):
    # Mirrors the safe_name logic in build-blocklist.sh.
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]", "-", text.lower())).strip("-")


def category_sort_key(name):
    rank = CATEGORY_ORDER.index(name) if name in CATEGORY_ORDER else len(CATEGORY_ORDER)
    return rank, name


def count_prefixes(path):
    if not os.path.exists(path):
        return 0
    with open(path) as f:
        return sum(1 for line in f if line.strip())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="public/manifest.json")
    args = parser.parse_args()

    with open("asn.json") as f:
        asns = json.load(f)

    providers = []
    for entry in asns:
        category = slug(entry.get("category") or "") or "uncategorized"
        path = f"individual_blocklists/{slug(entry['name'])}.txt"
        providers.append(
            {
                "asn": entry["asn"],
                "name": entry["name"],
                "category": category,
                "path": path,
                "prefixes": count_prefixes(path),
            }
        )

    categories = []
    names = {p["category"] for p in providers}
    for name in sorted(names, key=category_sort_key):
        path = f"lists/{name}.txt"
        categories.append(
            {
                "name": name,
                "path": path,
                "prefixes": count_prefixes(path),
                "asns": sum(1 for p in providers if p["category"] == name),
            }
        )

    with open(IMPORT_SCRIPT, "rb") as f:
        script_sha256 = hashlib.sha256(f.read()).hexdigest()

    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True
    ).stdout.strip()

    manifest = {
        "repo": "aaronburt/vpn-block-list",
        "commit": commit,
        "combined": {"path": "vpn-blocklist.txt", "prefixes": count_prefixes("vpn-blocklist.txt")},
        "import_script": {"path": IMPORT_SCRIPT, "sha256": script_sha256},
        "categories": categories,
        "providers": providers,
    }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print(f"Manifest written to {args.out}")


if __name__ == "__main__":
    main()
