# Contributing to Traefik VPN Blocklist

Thank you for your interest in contributing! Contributions from the community help keep this blocklist accurate and up-to-date.

## How to Contribute

### Adding or Removing an ASN Provider

The primary way to contribute to this project is by adding new VPN/Proxy/Data Center Autonomous System Numbers (ASNs) to the blocklist.

1. Fork the repository and clone it locally.
2. Open the `asn.json` file.
3. Add a new entry to the JSON array (or modify an existing one).
   - `asn`: The AS Number (string).
   - `name`: A short, descriptive name for the provider.
   - `description`: (Optional) Additional context about the provider.
   
   Example:
   ```json
   {
     "asn": "12345",
     "name": "Example VPN",
     "description": "Commercial VPN Provider"
   }
   ```
4. Do not run the build scripts manually unless you are testing changes to the scripts themselves. The GitHub Action will automatically rebuild the lists when your changes are merged.

### Testing Locally

If you modify the build scripts (`scripts/build-blocklist.sh` or `scripts/build-crowdsec.sh`):

1. Ensure you have `jq` and `curl` installed on your system.
2. Run the blocklist script: `./scripts/build-blocklist.sh`
3. Run the CrowdSec script: `./scripts/build-crowdsec.sh`
4. Verify the outputs in the `individual_blocklists/` and `crowdsec/` directories.

## Commit Message Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for our commit messages. This helps automate our release notes and provides a clear history.

Please prefix your commit messages with one of the following:

- `feat:` A new feature (e.g., adding a new ASN)
- `fix:` A bug fix (e.g., removing a false positive ASN)
- `docs:` Documentation only changes
- `chore:` Maintenance tasks, dependency updates, etc.
- `style:` Formatting, missing semi-colons, etc.
- `refactor:` Code change that neither fixes a bug nor adds a feature

Example: `feat: add Example VPN ASN 12345`

## Submitting a Pull Request

1. Create a new branch from `main` (`git checkout -b feat/add-example-vpn`).
2. Make your changes following the guidelines above.
3. Commit your changes using Conventional Commits.
4. Push your branch to your fork (`git push origin feat/add-example-vpn`).
5. Open a Pull Request against the `main` branch.
6. Fill out the Pull Request template completely.

## Code of Conduct

Please note that this project is released with a [Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
