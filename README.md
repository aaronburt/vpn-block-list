# Traefik VPN Blocklist

A dynamically generated Traefik IP blocklist containing Autonomous System Numbers (ASNs) commonly associated with consumer VPNs, proxies, and commercial data centers.

## Usage

The blocklist is updated daily via GitHub Actions. It pulls fresh ASN prefixes and formats them for use with Traefik's `IPAllowList` or `IPWhiteList` middleware file providers.

You can point your Traefik configuration directly to the raw files hosted in this repository:
- **Combined List**: [https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt)
- **Individual Provider Lists**: Browse available files in the [`/individual_blocklists`](https://github.com/aaronburt/vpn-block-list/tree/main/individual_blocklists) directory and use them via `https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/individual_blocklists/<filename>.txt`.

## Managing ASNs (Once Forked)

To add or remove monitored providers:
1. Edit `asn.json`
2. Add the provider's `asn` (number), `name`, and optional `description`.
3. Commit and push. The GitHub Action will automatically rebuild the lists.
