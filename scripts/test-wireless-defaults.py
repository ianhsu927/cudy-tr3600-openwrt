#!/usr/bin/env python3
"""Run the real mac80211 ucode generator with mocked board/UCI input."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ucode, source = sys.argv[1:]
source = Path(source).read_text()
imports = 'import { readfile } from "fs";\nimport * as uci from \'uci\';'
assert source.count(imports) == 1, "Upstream imports changed; review test adapter"


def generate(board, existing=None):
    # Only external reads are replaced. Run the production generator unchanged.
    adapter = "\n".join([
        "let test_board = " + json.dumps(board) + ";",
        "let test_existing = " + json.dumps(existing or {}) + ";",
        "function readfile(path) {",
        "  if (path == '/etc/board.json') return sprintf('%J', test_board);",
        "  return '02:00:00:00:00:01\\n';",
        "}",
        "let uci = { cursor: () => ({ get_all: () => test_existing }) };",
    ])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".uc") as script:
        script.write(source.replace(imports, adapter))
        script.flush()
        result = subprocess.run([ucode, script.name], check=True,
                                capture_output=True, text=True).stdout
    values = {}
    for line in result.splitlines():
        if line.startswith("set "):
            key, value = line[4:].split("=", 1)
            values[key] = value.strip("'")
    return values, result


def fixture(reverse=False, model="cudy,tr3600-v1", mode="eht", width=160):
    entries = [
        ("phy0", {"path": "pci/2g", "info": {"bands": {
            "2G": {"max_width": 40, "he": True, "default_channel": 1}}}}),
        ("phy1", {"path": "pci/5g", "info": {"bands": {
            "5G": {"max_width": width, mode: True, "default_channel": 36}}}}),
    ]
    return {"model": {"id": model}, "wlan": dict(reversed(entries) if reverse else entries)}


def check_defaults(board, expected_mode="EHT160"):
    values, result = generate(board)
    radios = [key for key, value in values.items() if value == "wifi-device"]
    assert len(radios) == 2, result
    for radio in radios:
        band = values[radio + ".band"]
        iface = "wireless.default_" + radio.split(".")[1]
        disabled = "1" if band == "2g" else "0"
        assert values[radio + ".disabled"] == disabled, result
        assert values[iface + ".disabled"] == disabled, result
        assert values[iface + ".ssid"] == "TR3600", result
        assert values[iface + ".key"] == "password", result
        assert values[iface + ".encryption"] == "sae-mixed", result
        assert values[iface + ".mode"] == "ap", result
        assert values[iface + ".network"] == "lan", result
        assert values[radio + ".country"] == board["wlan"].get("defaults", {}).get("country", ""), result
        if band == "5g":
            assert values[radio + ".htmode"] == expected_mode, result
            assert values[radio + ".channel"] == "auto", result
        else:
            assert values[radio + ".htmode"] == "HE20", result
    assert result.endswith("commit wireless\n"), result
    return values


for reverse in (False, True):
    check_defaults(fixture(reverse))
print("PASS: fresh dual-radio defaults in both enumeration orders")
check_defaults(fixture(mode="he"), "HE160")
check_defaults(fixture(width=80), "EHT80")
check_defaults(fixture(width=320), "EHT160")
print("PASS: detected PHY mode retained; width never exceeds hardware or 160 MHz")

board = fixture()
board["wlan"]["defaults"] = {"country": "DE"}  # Test data, not a firmware default.
check_defaults(board)
print("PASS: regulatory country preserved, never invented")

board = fixture()
bands = {**board["wlan"]["phy0"]["info"]["bands"], **board["wlan"]["phy1"]["info"]["bands"]}
board["wlan"] = {"phy0": {"path": "pci/shared", "info": {"bands": bands, "radios": [
    {"index": 1, "bands": {"5G": {"default_channel": 36}}},
    {"index": 0, "bands": {"2G": {"default_channel": 1}}},
]}}}
check_defaults(board)
print("PASS: multiple band radios on one PHY")

board = fixture()
existing = {}
for i, band in enumerate(("2g", "5g")):
    existing[f"saved{i}"] = {".type": "wifi-device", "path": f"pci/{band}",
                            "band": band, "htmode": "HE80", "disabled": "0"}
    existing[f"ap{i}"] = {".type": "wifi-iface", "device": f"saved{i}",
                         "ssid": "KeepMe", "key": "ExistingPrivateValue"}
assert generate(board, existing) == ({}, "")
# Existing sections identified by PHY or MAC must also stay untouched.
for identity in ({"phy": "phy0"}, {"macaddr": "02:00:00:00:00:01"}):
    one = {"model": board["model"], "wlan": {"phy0": board["wlan"]["phy0"]}}
    assert generate(one, {"saved": {".type": "wifi-device", **identity}}) == ({}, "")
print("PASS: retained sysupgrade settings and repeated detection are not overwritten")

values, result = generate(fixture(model="other,device"))
assert "TR3600" not in result and "password" not in result
for radio in ("wireless.radio0", "wireless.radio1"):
    assert radio + ".disabled" not in values
    iface = "wireless.default_" + radio.split(".")[1]
    assert values[iface + ".ssid"] == "OpenWrt"
    assert values[iface + ".disabled"] == "1"
assert values["wireless.radio1.htmode"] == "EHT80"
assert generate({"model": {"id": "cudy,tr3600-v1"}}) == ({}, "")
print("PASS: unrelated boards and absent hardware retain upstream behavior")
