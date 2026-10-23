import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
SCRIPTS = REPO / "scripts"

sys.path.insert(0, str(SCRIPTS))


def load_script(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_executable(path, body):
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


@pytest.fixture
def workdir(tmp_path):
    """An empty build directory with a `curl` stub that downloads nothing.

    Tests drop pre-fetched ASN JSON into asn_list/ instead, so builds run offline.
    """
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    write_executable(bin_dir / "curl", "#!/bin/sh\nexit 0\n")
    work = tmp_path / "work"
    (work / "asn_list").mkdir(parents=True)
    (work / "crowdsec").mkdir()
    shutil.copy(REPO / "crowdsec" / "docker_crowdsec_ban_import.sh", work / "crowdsec")
    return work


def build_env(work):
    """Environment with the offline curl stub (kept next to the work dir) first on PATH."""
    bin_dir = work.parent / "bin"
    return {**os.environ, "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}


def write_asns(work, entries, prefixes):
    """entries: asn.json content; prefixes: {asn: [cidr, ...]} served as upstream data."""
    (work / "asn.json").write_text(json.dumps(entries))
    for asn, nets in prefixes.items():
        v4 = [n for n in nets if ":" not in n]
        v6 = [n for n in nets if ":" in n]
        data = {"prefixes": {"ipv4": v4, "ipv6": v6}}
        (work / "asn_list" / f"{asn}.json").write_text(json.dumps(data))


def run_build(work, *, env=None):
    return subprocess.run(
        ["bash", str(SCRIPTS / "build-blocklist.sh")],
        cwd=work,
        env={**build_env(work), **(env or {})},
        capture_output=True,
        text=True,
    )


def run_full_build(work):
    result = run_build(work)
    assert result.returncode == 0, result.stderr
    for cmd in (
        ["bash", str(SCRIPTS / "build-crowdsec.sh")],
        [sys.executable, str(SCRIPTS / "build-manifest.py"), "--out", "public/manifest.json"],
    ):
        result = subprocess.run(cmd, cwd=work, env=build_env(work), capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
