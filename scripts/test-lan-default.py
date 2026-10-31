#!/usr/bin/env python3
"""Check generated LAN defaults without touching the host network or UCI."""
import pathlib
import re
import subprocess
import sys

source = pathlib.Path(sys.argv[1]).read_text()
assert '[ -s /etc/config/network -a -s /etc/config/system ] && exit 0' in source
assert 'if [ ! -s /etc/config/network ]; then' in source
assert 'lan) ipad=${ipaddr:-"192.168.10.1"} ;;' in source
assert 'netm=${netmask:-"255.255.255.0"}' in source
match = re.search(r'\t\t\tcase "\$1" in\n.*?\t\t\tesac', source, re.S)
assert match, 'Cannot locate static address selection'
for interface, override, expected in [
    ('lan', '', '192.168.10.1'),
    ('lan', '192.168.8.1', '192.168.8.1'),
    ('guest', '', '192.168.2.1'),
    ('guest', '10.20.30.1', '10.20.30.1'),
]:
    script = 'addr_offset=2\nipaddr=$2\n' + match[0] + '\nprintf "%s" "$ipad"\n'
    result = subprocess.check_output(['bash', '-c', script, 'test', interface, override], text=True)
    assert result == expected, (interface, override, result, expected)
    print(f'PASS: {interface}, override={override or "none"} -> {result}')
print('PASS: /24 netmask and retained network configuration guards unchanged')
