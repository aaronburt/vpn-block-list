"""The validator must actually catch broken outputs, otherwise it guarantees nothing."""

import pytest
from conftest import run_full_build, write_asns
from validate_outputs import Validator

ENTRIES = [
    {"asn": 1, "name": "Example VPN", "category": "vpn"},
    {"asn": 2, "name": "Example Cloud", "category": "hosting"},
]
PREFIXES = {1: ["1.2.3.0/24", "2001:db8:1::/48"], 2: ["5.5.5.0/24"]}


@pytest.fixture
def built(workdir):
    write_asns(workdir, ENTRIES, PREFIXES)
    run_full_build(workdir)
    assert Validator(str(workdir)).run() == []
    return workdir


def append(path, text):
    path.write_text(path.read_text() + text)


def errors(work):
    return "\n".join(Validator(str(work)).run())


def test_catches_private_ranges(built):
    append(built / "vpn-blocklist.txt", "192.168.0.0/16\n")
    assert "reserved/private" in errors(built)


def test_catches_uncollapsed_or_unsorted_list(built):
    (built / "vpn-blocklist.txt").write_text("5.5.5.0/24\n1.2.3.0/25\n1.2.3.128/25\n")
    assert "not sorted and fully collapsed" in errors(built)


def test_catches_non_canonical_and_invalid_lines(built):
    # Host bits set and garbage are invalid; uppercase IPv6 parses but is not canonical.
    append(built / "vpn-blocklist.txt", "1.2.3.5/24\nnonsense\n2001:DB8::/32\n")
    out = errors(built)
    assert "not a valid CIDR: '1.2.3.5/24'" in out
    assert "not a valid CIDR: 'nonsense'" in out
    assert "not in canonical form: '2001:DB8::/32'" in out


def test_catches_wrong_family_in_split_file(built):
    append(built / "vpn-blocklist-ipv4.txt", "2001:db8::/32\n")
    assert "not IPv4" in errors(built)


def test_catches_split_files_out_of_sync(built):
    (built / "lists" / "vpn-ipv4.txt").write_text("")
    assert "do not match the combined file" in errors(built)


def test_catches_category_list_missing_ranges(built):
    (built / "lists" / "hosting.txt").write_text("")
    (built / "lists" / "hosting-ipv4.txt").write_text("")
    assert "do not cover exactly" in errors(built)


def test_catches_stale_crowdsec_csv(built):
    append(built / "crowdsec" / "decisions.csv", "24h,ban,VPN Blocklist,range,7.7.7.0/24\n")
    assert "do not match vpn-blocklist.txt" in errors(built)


def test_catches_bad_asn_json(built):
    (built / "asn.json").write_text(
        '[{"asn": 1, "name": "A", "category": "vpn"},'
        ' {"asn": 1, "name": "B", "category": "bogus"},'
        ' {"asn": "3", "name": "C", "category": "vpn"}]'
    )
    out = errors(built)
    assert "duplicate asn 1" in out
    assert "category must be one of" in out
    assert "asn must be a positive integer" in out


def test_catches_readme_checksum_drift(built):
    (built / "README.md").write_text('echo "' + "0" * 64 + '  /tmp/cs_import.sh"\n')
    assert "cron checksum" in errors(built)


def test_catches_missing_file(built):
    (built / "lists" / "vpn-ipv6.txt").unlink()
    assert "lists/vpn-ipv6.txt: missing" in errors(built)
