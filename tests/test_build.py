"""Run the real build scripts offline against fixture data and validate every format."""

import json

from conftest import run_build, run_full_build, write_asns
from validate_outputs import Validator

ENTRIES = [
    {"asn": 1, "name": "Example VPN", "category": "vpn"},
    {"asn": 2, "name": "Example Leased", "category": "vpn-infrastructure"},
    {"asn": 3, "name": "Example Cloud", "category": "hosting", "description": "cloud"},
]
PREFIXES = {
    1: ["1.2.3.0/24", "1.2.2.0/24", "1.2.2.0/24", "2001:db8:1::/48", "2001:db8:2::/109"],
    2: ["5.5.5.0/24", "999.1.1.1/24"],
    3: ["8.8.0.0/16", "8.8.8.0/24", "2001:db8:3::/48"],
}


def lines(path):
    return path.read_text().splitlines()


def test_every_output_format_is_valid(workdir):
    write_asns(workdir, ENTRIES, PREFIXES)
    run_full_build(workdir)
    assert Validator(str(workdir)).run(manifest="public/manifest.json") == []


def test_merge_split_and_categories(workdir):
    write_asns(workdir, ENTRIES, PREFIXES)
    run_full_build(workdir)

    # Adjacent /24s join, duplicates and contained prefixes disappear, invalid lines are dropped.
    assert lines(workdir / "lists" / "vpn.txt") == [
        "1.2.2.0/23",
        "2001:db8:1::/48",
        "2001:db8:2::/109",
    ]
    assert lines(workdir / "lists" / "hosting-ipv4.txt") == ["8.8.0.0/16"]
    assert lines(workdir / "lists" / "vpn-infrastructure-ipv6.txt") == []
    assert lines(workdir / "individual_blocklists" / "example-cloud-ipv6.txt") == [
        "2001:db8:3::/48"
    ]
    assert lines(workdir / "vpn-blocklist-ipv4.txt") == ["1.2.2.0/23", "5.5.5.0/24", "8.8.0.0/16"]

    csv = lines(workdir / "crowdsec" / "decisions.csv")
    assert csv[0] == "duration,type,reason,scope,value"
    assert csv[1:] == [
        f"24h,ban,VPN Blocklist,range,{n}" for n in lines(workdir / "vpn-blocklist.txt")
    ]

    manifest = json.loads((workdir / "public" / "manifest.json").read_text())
    assert [c["name"] for c in manifest["categories"]] == ["vpn", "vpn-infrastructure", "hosting"]


def test_rebuild_does_not_reread_split_files(workdir):
    write_asns(workdir, ENTRIES, PREFIXES)
    run_full_build(workdir)
    first = sorted(p.name for p in (workdir / "lists").iterdir())
    run_full_build(workdir)
    assert sorted(p.name for p in (workdir / "lists").iterdir()) == first


def test_missing_category_defaults_to_uncategorized(workdir):
    write_asns(workdir, [{"asn": 1, "name": "No Category"}], {1: ["1.2.3.0/24"]})
    assert run_build(workdir).returncode == 0
    assert lines(workdir / "lists" / "uncategorized.txt") == ["1.2.3.0/24"]


def test_fails_when_too_many_asns_are_missing(workdir):
    write_asns(workdir, ENTRIES, {1: PREFIXES[1]})
    result = run_build(workdir, env={"MAX_MISSING_ASNS": "1"})
    assert result.returncode != 0
    assert "2 ASNs had no data" in result.stderr


def test_fails_when_list_shrinks_too_much(workdir):
    write_asns(workdir, ENTRIES, PREFIXES)
    (workdir / "vpn-blocklist.txt").write_text("".join(f"9.9.{i}.0/24\n" for i in range(100)))
    result = run_build(workdir)
    assert result.returncode != 0
    assert "shrank" in result.stderr
