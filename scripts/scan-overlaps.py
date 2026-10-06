import sys
import ipaddress

def process_file(filepath, in_place=False):
    v4 = []
    v6 = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            net = ipaddress.ip_network(line)
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

    print(f"{filepath}: {orig_total} -> {merged_total} ({diff} redundant prefixes)")

    if in_place:
        with open(filepath, 'w') as f:
            for net in merged:
                f.write(f"{net}\n")

if __name__ == '__main__':
    args = sys.argv[1:]
    in_place = False
    if '--merge' in args:
        in_place = True
        args.remove('--merge')
    if not args:
        args = ['vpn-blocklist.txt']
    for path in args:
        process_file(path, in_place=in_place)
