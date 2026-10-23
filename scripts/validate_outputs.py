"""Validate asn.json and every published blocklist format.

Run from the repository root (or pass --root). Exits non-zero and prints each
problem if anything is wrong, so the update workflow can refuse to publish.
"""

import argparse
import glob
import hashlib
import ipaddress
import json
import os
import re
import sys

ALLOWED_CATEGORIES = {"vpn", "vpn-infrastructure", "hosting"}
ASN_KEYS = {"asn", "name", "category", "description"}
IMPORT_SCRIPT = "crowdsec/docker_crowdsec_ban_import.sh"
CSV_HEADER = "duration,type,reason,scope,value"
CSV_ROW = re.compile(r"^24h,ban,VPN Blocklist,range,(\S+)$")

# Ranges that must never be published: blocking them could lock users out of
# their own network or break the internet for them.
SPECIAL_RANGES = [
    ipaddress.ip_network(n)
    for n in (
        "0.0.0.0/8",
        "10.0.0.0/8",
        "100.64.0.0/10",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "224.0.0.0/4",
        "240.0.0.0/4",
        "::/128",
        "::1/128",
        "fc00::/7",
        "fe80::/10",
        "ff00::/8",
    )
]


def slug(text):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]", "-", text.lower())).strip("-")


def is_split_file(path):
    return path.endswith(("-ipv4.txt", "-ipv6.txt"))


def collapse(nets):
    v4 = list(ipaddress.collapse_addresses(n for n in nets if n.version == 4))
    v6 = list(ipaddress.collapse_addresses(n for n in nets if n.version == 6))
    return sorted(v4) + sorted(v6)


class Validator:
    def __init__(self, root):
        self.root = root
        self.errors = []

    def error(self, message):
        self.errors.append(message)

    def path(self, rel):
        return os.path.join(self.root, rel)

    def check_asn_json(self):
        try:
            with open(self.path("asn.json")) as f:
                entries = json.load(f)
        except (OSError, ValueError) as e:
            self.error(f"asn.json: cannot be read as JSON ({e})")
            return []
        if not isinstance(entries, list):
            self.error("asn.json: top level must be a list")
            return []

        seen_asns, seen_slugs = set(), set()
        for i, entry in enumerate(entries):
            where = f"asn.json[{i}]"
            if not isinstance(entry, dict):
                self.error(f"{where}: must be an object")
                continue
            unknown = set(entry) - ASN_KEYS
            if unknown:
                self.error(f"{where}: unknown keys {sorted(unknown)}")
            asn = entry.get("asn")
            if not isinstance(asn, int) or isinstance(asn, bool) or asn <= 0:
                self.error(f"{where}: asn must be a positive integer")
            elif asn in seen_asns:
                self.error(f"{where}: duplicate asn {asn}")
            else:
                seen_asns.add(asn)
            name = entry.get("name")
            if not isinstance(name, str) or not slug(name):
                self.error(f"{where}: name must be a non-empty string")
            elif slug(name) in seen_slugs:
                self.error(f"{where}: name '{name}' maps to an existing file name")
            else:
                seen_slugs.add(slug(name))
            if entry.get("category") not in ALLOWED_CATEGORIES:
                self.error(f"{where}: category must be one of {sorted(ALLOWED_CATEGORIES)}")
            if "description" in entry and not isinstance(entry["description"], str):
                self.error(f"{where}: description must be a string")
        return entries

    def read_list(self, rel):
        """Parse a list file, reporting any line that is not in canonical published form."""
        try:
            with open(self.path(rel), "rb") as f:
                raw = f.read()
        except OSError:
            self.error(f"{rel}: missing")
            return None
        if b"\r" in raw:
            self.error(f"{rel}: contains CR characters")
        text = raw.decode("utf-8", errors="replace")
        if text and not text.endswith("\n"):
            self.error(f"{rel}: does not end with a newline")

        nets = []
        for lineno, line in enumerate(text.splitlines(), 1):
            try:
                net = ipaddress.ip_network(line)
            except ValueError:
                self.error(f"{rel}:{lineno}: not a valid CIDR: {line!r}")
                continue
            if str(net) != line:
                self.error(f"{rel}:{lineno}: not in canonical form: {line!r}")
            nets.append(net)
        return nets

    def check_list(self, rel, family=None):
        nets = self.read_list(rel)
        if nets is None:
            return None
        if nets != collapse(nets):
            self.error(f"{rel}: not sorted and fully collapsed (IPv4 first, then IPv6)")
        if family and any(n.version != family for n in nets):
            self.error(f"{rel}: contains addresses that are not IPv{family}")
        for net in nets:
            for special in SPECIAL_RANGES:
                if net.version == special.version and net.overlaps(special):
                    self.error(f"{rel}: {net} overlaps reserved/private range {special}")
        return nets

    def check_list_with_splits(self, rel):
        nets = self.check_list(rel)
        stem = rel[: -len(".txt")]
        v4 = self.check_list(f"{stem}-ipv4.txt", family=4)
        v6 = self.check_list(f"{stem}-ipv6.txt", family=6)
        if nets is not None and v4 is not None and v6 is not None and nets != v4 + v6:
            self.error(f"{rel}: -ipv4/-ipv6 files do not match the combined file")
        return nets

    def check_lists(self, entries):
        combined = self.check_list_with_splits("vpn-blocklist.txt")
        if not combined:
            self.error("vpn-blocklist.txt: is empty")

        def base_lists(pattern):
            return sorted(p for p in glob.glob(self.path(pattern)) if not is_split_file(p))

        category_nets, provider_nets = [], []
        for path in base_lists("lists/*.txt"):
            category_nets += self.check_list_with_splits(os.path.relpath(path, self.root)) or []
        for path in base_lists("individual_blocklists/*.txt"):
            provider_nets += self.check_list_with_splits(os.path.relpath(path, self.root)) or []

        for category in {e.get("category") for e in entries if isinstance(e, dict)}:
            if category in ALLOWED_CATEGORIES and not os.path.exists(
                self.path(f"lists/{category}.txt")
            ):
                self.error(f"lists/{category}.txt: missing for category in asn.json")

        if combined is not None:
            if collapse(category_nets) != combined:
                self.error("lists/*.txt together do not cover exactly vpn-blocklist.txt")
            if collapse(provider_nets) != combined:
                self.error(
                    "individual_blocklists/*.txt together do not cover exactly vpn-blocklist.txt"
                )
        return combined

    def check_crowdsec(self, combined):
        rel = "crowdsec/decisions.csv"
        try:
            with open(self.path(rel)) as f:
                lines = f.read().splitlines()
        except OSError:
            self.error(f"{rel}: missing")
            return
        if not lines or lines[0] != CSV_HEADER:
            self.error(f"{rel}: header must be '{CSV_HEADER}'")
            return
        values = []
        for lineno, line in enumerate(lines[1:], 2):
            match = CSV_ROW.match(line)
            if not match:
                self.error(f"{rel}:{lineno}: malformed row: {line!r}")
                continue
            values.append(match.group(1))
        if combined is not None and values != [str(n) for n in combined]:
            self.error(f"{rel}: values do not match vpn-blocklist.txt")

    def check_readme_checksum(self):
        readme = self.path("README.md")
        if not os.path.exists(readme):
            return
        with open(self.path(IMPORT_SCRIPT), "rb") as f:
            actual = hashlib.sha256(f.read()).hexdigest()
        with open(readme) as f:
            pinned = set(re.findall(r'echo "([0-9a-f]{64})  /tmp/cs_import\.sh"', f.read()))
        if pinned != {actual}:
            self.error(
                f"README.md: cron checksum {sorted(pinned)} does not match {IMPORT_SCRIPT} ({actual})"
            )

    def check_manifest(self, rel):
        try:
            with open(self.path(rel)) as f:
                manifest = json.load(f)
        except (OSError, ValueError) as e:
            self.error(f"{rel}: cannot be read as JSON ({e})")
            return
        with open(self.path(IMPORT_SCRIPT), "rb") as f:
            actual = hashlib.sha256(f.read()).hexdigest()
        if manifest.get("import_script", {}).get("sha256") != actual:
            self.error(f"{rel}: import_script.sha256 does not match {IMPORT_SCRIPT}")
        for item in [manifest.get("combined", {})] + manifest.get("categories", []):
            path = item.get("path", "")
            if not os.path.exists(self.path(path)):
                self.error(f"{rel}: references missing file {path!r}")

    def run(self, manifest=None):
        entries = self.check_asn_json()
        combined = self.check_lists(entries)
        self.check_crowdsec(combined)
        self.check_readme_checksum()
        if manifest:
            self.check_manifest(manifest)
        return self.errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--manifest", help="also validate this manifest (path relative to root)")
    args = parser.parse_args()

    errors = Validator(args.root).run(manifest=args.manifest)
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        sys.exit(1)
    print("All outputs valid.")


if __name__ == "__main__":
    main()
