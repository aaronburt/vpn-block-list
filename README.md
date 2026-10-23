# VPN Blocklist

A dynamically generated IP blocklist of the networks (ASNs) behind common consumer VPNs, proxies, and commercial data centers, for self-hosters who want to block that traffic on their own endpoints.

> [!NOTE]
> The list currently includes general-purpose hosting providers (for example OVH, DigitalOcean, Hetzner, Vultr and Linode) alongside VPN providers. Blocking them can also block legitimate traffic such as federation partners, webhooks, uptime monitors, or your own VPS. Use the individual provider lists if you only want specific networks.

## Usage

The blocklist is rebuilt daily via GitHub Actions from public ASN prefix data. Each file is plain text with one IPv4 or IPv6 CIDR per line:

- **Combined List**: [https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/vpn-blocklist.txt)
- **Individual Provider Lists**: Browse available files in the [`/individual_blocklists`](https://github.com/aaronburt/vpn-block-list/tree/main/individual_blocklists) directory and use them via `https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/individual_blocklists/<filename>.txt`.

### Traefik

Traefik has no built-in IP deny-list middleware, and `IPAllowList` does the opposite (it only lets the listed ranges through), so do not load this list into it. To block these ranges in front of Traefik, use the [CrowdSec integration](#crowdsec-integration) with the CrowdSec Traefik bouncer, or a deny-IP plugin from the [Traefik plugin catalog](https://plugins.traefik.io/).

## Managing ASNs (Once Forked)

To add or remove monitored providers:
1. Edit `asn.json`
2. Add the provider's `asn` (number), `name`, and optional `description`.
3. Commit and push. The GitHub Action will automatically rebuild the lists.

## CrowdSec Integration

If you use CrowdSec, you can import the pre-formatted decisions CSV directly or run the provided import runner:

- **Direct CSV Import**: Download [`crowdsec/decisions.csv`](https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/decisions.csv) and run `docker exec -i crowdsec cscli decisions import --input - --format csv < decisions.csv`
- **Import Runner**: Run on your Docker host:

```bash
curl -sSL "https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/docker_crowdsec_ban_import.sh" | bash
```

*Note: The script assumes your CrowdSec container is named `crowdsec`.*

### Automation (Cron)

To keep your CrowdSec blocklist automatically synchronized, you can add a daily cronjob. Open your root crontab (`sudo crontab -e`) and add the following entry to run the sync at 3:00 AM every day:

```bash
0 3 * * * curl -sSL "https://cdn.jsdelivr.net/gh/aaronburt/vpn-block-list@main/crowdsec/docker_crowdsec_ban_import.sh" -o /tmp/cs_import.sh && echo "e546da7d8f418f6a6cfed5ed07a5153cb9615fba5231382ac257c60408f819dc  /tmp/cs_import.sh" | sha256sum -c - >/dev/null 2>&1 && bash /tmp/cs_import.sh >/dev/null 2>&1 && echo "$(date): SUCCESS" >> ~/cs_import.log || echo "$(date): FAILED" >> ~/cs_import.log; rm -f /tmp/cs_import.sh
```

> [!WARNING]
> The above cronjob includes a SHA256 checksum to ensure the script's integrity before running. If `docker_crowdsec_ban_import.sh` changes, its hash will change and the cronjob will abort safely (it logs `FAILED` to `~/cs_import.log`). Check that log, then recalculate the hash (`curl -sSL <url> | sha256sum`) after reviewing the new script, and update your crontab.
