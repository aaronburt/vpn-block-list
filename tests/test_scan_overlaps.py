from conftest import load_script

scan = load_script("scan_overlaps", "scan-overlaps.py")


def test_merge_in_place_collapses_and_sorts(tmp_path):
    path = tmp_path / "list.txt"
    path.write_text("2001:db8::/48\n10.0.1.0/24\n10.0.0.0/24\n10.0.0.0/25\n\n")
    scan.process_file(str(path), in_place=True)
    assert path.read_text() == "10.0.0.0/23\n2001:db8::/48\n"


def test_invalid_lines_are_skipped_not_fatal(tmp_path, capsys):
    path = tmp_path / "list.txt"
    path.write_text("not-an-ip\n300.1.1.0/24\n1.1.1.0/24\n")
    scan.process_file(str(path), in_place=True)
    assert path.read_text() == "1.1.1.0/24\n"
    assert "2 invalid" in capsys.readouterr().out


def test_split_always_writes_both_families(tmp_path):
    path = tmp_path / "list.txt"
    path.write_text("1.1.1.0/24\n")
    scan.process_file(str(path), in_place=True, split=True)
    assert (tmp_path / "list-ipv4.txt").read_text() == "1.1.1.0/24\n"
    assert (tmp_path / "list-ipv6.txt").read_text() == ""
