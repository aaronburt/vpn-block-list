# VPN Blocklist

A dynamically generated IP blocklist of the networks (ASNs) behind common consumer VPNs, proxies, and commercial data centers, for self-hosters who want to block that traffic on their own endpoints.

> [!NOTE]
> The list currently includes general-purpose hosting providers (for example OVH, DigitalOcean, Hetzner, Vultr and Linode) alongside VPN providers. Blocking them can also block legitimate traffic such as federation partners, webhooks, uptime monitors, or your own VPS. Use the [category lists](#category-lists) or the individual provider lists if you only want specific networks.

## Usage

The blocklist is rebuilt daily via GitHub Actions from public ASN prefix data. Each file is plain text with one IPv4 or IPv6 CIDR per line:

- **Combined List**: [https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt)
- **Individual Provider Lists**: Browse available files in the [`/individual_blocklists`](https://github.com/aaronburt/vpn-block-list/tree/main/individual_blocklists) directory and use them via `https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/individual_blocklists/<filename>.txt`.

### Category lists

Every ASN in `asn.json` has a `category`, and each category is published as its own list. The combined `vpn-blocklist.txt` and the CrowdSec defaults still contain every category, so existing setups are unchanged.

| Category | What it contains | List |
|---|---|---|
| `vpn` | Networks operated by VPN providers themselves (Mullvad, Proton, Surfshark, NordVPN, ExpressVPN, IPVanish) | [`lists/vpn.txt`](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/lists/vpn.txt) |
| `vpn-infrastructure` | Hosting networks that VPN and proxy brands lease heavily (M247, Datacamp, Clouvider, Zenlayer and similar) | [`lists/vpn-infrastructure.txt`](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/lists/vpn-infrastructure.txt) |
| `hosting` | General-purpose cloud and VPS providers (OVH, DigitalOcean, Hetzner, Vultr, Linode and similar) | [`lists/hosting.txt`](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/lists/hosting.txt) |

`vpn` plus `vpn-infrastructure` is the lowest-risk starting point for most self-hosters. Add `hosting` only if you don't expect legitimate traffic from cloud servers.

### Traefik

Traefik has no built-in IP deny-list middleware, and `IPAllowList` does the opposite (it only lets the listed ranges through), so do not load this list into it. To block these ranges in front of Traefik, use the [CrowdSec integration](#crowdsec-integration) with the CrowdSec Traefik bouncer, or a deny-IP plugin from the [Traefik plugin catalog](https://plugins.traefik.io/).

## Managing ASNs (Once Forked)

To add or remove monitored providers:
1. Edit `asn.json`
2. Add the provider's `asn` (number), `name`, `category` (`vpn`, `vpn-infrastructure` or `hosting`), and optional `description`. Entries without a category go into `lists/uncategorized.txt` and the combined list.
3. Commit and push. The GitHub Action will automatically rebuild the lists.

## CrowdSec Integration

If you use CrowdSec, you can import the pre-formatted decisions CSV directly or run the provided import runner:

- **Direct CSV Import**: Download [`crowdsec/decisions.csv`](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/decisions.csv) and run `docker exec -i crowdsec cscli decisions import --input - --format csv < decisions.csv`
- **Import Runner**: Run on your Docker host:

```bash
curl -sSL "https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/docker_crowdsec_ban_import.sh" | bash
```

*Note: The script assumes your CrowdSec container is named `crowdsec`. Set `CROWDSEC_CONTAINER` to override it.*

By default the runner imports every category. To import only some, set `CATEGORIES` to a space-separated list:

```bash
curl -sSL "https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/docker_crowdsec_ban_import.sh" | CATEGORIES="vpn vpn-infrastructure" bash
```

The script is the same whichever categories you choose, so the checksum below still applies. In the cron entry, use `CATEGORIES="vpn vpn-infrastructure" bash /tmp/cs_import.sh` instead of `bash /tmp/cs_import.sh`.

### Automation (Cron)

To keep your CrowdSec blocklist automatically synchronized, you can add a daily cronjob. Open your root crontab (`sudo crontab -e`) and add the following entry to run the sync at 3:00 AM every day:

```bash
0 3 * * * curl -sSL "https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/docker_crowdsec_ban_import.sh" -o /tmp/cs_import.sh && echo "c82f4b5b652caa0b23ffa082faf840150b0a0c97024f0921f1357a75d2b691f7  /tmp/cs_import.sh" | sha256sum -c - >/dev/null 2>&1 && bash /tmp/cs_import.sh >/dev/null 2>&1 && echo "$(date): SUCCESS" >> ~/cs_import.log || echo "$(date): FAILED" >> ~/cs_import.log; rm -f /tmp/cs_import.sh
```

> [!WARNING]
> The above cronjob includes a SHA256 checksum to ensure the script's integrity before running. If `docker_crowdsec_ban_import.sh` changes, its hash will change and the cronjob will abort safely (it logs `FAILED` to `~/cs_import.log`). Check that log, then recalculate the hash (`curl -sSL <url> | sha256sum`) after reviewing the new script, and update your crontab.
