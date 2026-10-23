import os
import sys
import ipaddress

def write_networks(path, nets):
    with open(path, 'w') as f:
        for net in nets:
            f.write(f"{net}\n")


def process_file(filepath, in_place=False, split=False):
    v4 = []
    v6 = []
    invalid = 0
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                net = ipaddress.ip_network(line, strict=False)
            except ValueError:
                print(f"{filepath}: skipping invalid prefix {line!r}", file=sys.stderr)
                invalid += 1
                continue
            if net.version == 4:
                v4.append(net)
            else:
                v6.append(net)

    c4 = list(ipaddress.collapse_addresses(v4))
    c6 = list(ipaddress.collapse_addresses(v6))
    merged = sorted(c4) + sorted(c6)

    orig_total = len(v4) + len(v6)
    merged_total = len(merged)
    diff = orig_total - merged_total

    print(f"{filepath}: {orig_total} -> {merged_total} ({diff} redundant prefixes, {invalid} invalid)")

    if in_place:
        write_networks(filepath, merged)

    if split:
        # Both files are always written so every list has stable -ipv4/-ipv6 URLs.
        stem, ext = os.path.splitext(filepath)
        write_networks(f"{stem}-ipv4{ext}", sorted(c4))
        write_networks(f"{stem}-ipv6{ext}", sorted(c6))

if __name__ == '__main__':
    args = sys.argv[1:]
    in_place = '--merge' in args
    split = '--split' in args
    args = [a for a in args if a not in ('--merge', '--split')]
    if not args:
        args = ['vpn-blocklist.txt']
    for path in args:
        process_file(path, in_place=in_place, split=split)
