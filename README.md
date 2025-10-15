# Release Directory List

A tool that generates PyPI Simple repository structures from GitHub releases, with integrated security scanning and Sigstore attestation.

## Overview

Automatically creates PyPI-compatible repositories from GitHub release assets and deploys them to GitHub Pages. Supports Nexus Repository Manager proxying for enterprise artifact management.

## Features

- PyPI Simple repository generation from GitHub releases
- Multi-platform support (Linux, macOS, Windows)
- SHA256 checksum verification
- Automated GitHub Actions deployment
- Nexus Repository Manager integration
- Security scanning with ClamAV and YARA
- Sigstore attestation for secure supply chain
- CLI tool for manual operations

## Prerequisites

- Go 1.21+
- GitHub repository with releases
- GitHub Pages enabled (optional)
- Nexus Repository Manager (optional, for proxying)

## Installation

```bash
make build
```

## CLI Usage

```bash
./bin/release-tool generate \
  --url https://api.github.com/repos/owner/repo/releases \
  --output releases \
  --project myproject \
  --log-level info
```

| Flag | Description |
|------|-------------|
| `--url` | Source URL to fetch releases from |
| `--output` | Output directory for generated structure |
| `--project` | Project name for PyPI repository |
| `--log-level` | Logging level (debug, info, warn, error) |

## Workflows

### PyPI Generation (`pypi-from-releases.yml`)

Automatically generates PyPI repositories on new releases:
- Downloads release assets
- Calculates SHA256 checksums
- Creates PyPI Simple HTML indexes
- Deploys to GitHub Pages

### Security Scan (`scan-python-release.yml`)

Proof-of-concept security scanning with Sigstore attestation:
- Downloads Python executable from python.org
- Scans with ClamAV (official Cisco Talos Docker image)
- Applies custom YARA rules
- Creates SLSA provenance attestations
- Generates comprehensive security report

#### Running Security Scan

```bash
# Manual trigger from Actions tab
1. Go to Actions → "Security Scan and Attestation POC"
2. Click "Run workflow"
```

#### Security Scan Outputs

- `security-scan-report-{run_id}.json` - Complete security audit report
- `python-predicate.json` - SLSA provenance data
- Attestation bundles and verification proofs
- Scan logs from all security tools

## Nexus Configuration

### Proxy Repositories

Create PyPI proxy repositories for each platform:

| Platform | Repository Name | Remote URL |
|----------|----------------|------------|
| Linux | `linux` | `https://username.github.io/repo-name/linux` |
| macOS | `mac` | `https://username.github.io/repo-name/mac` |
| Windows | `windows` | `https://username.github.io/repo-name/windows` |

**Note**: Omit `/simple/` from URLs - Nexus adds this automatically.

### Repository Group

Combine platforms into a single endpoint by creating a `pypi (group)` repository and adding the proxy repositories as members.

### Testing

```bash
# Download through Nexus
curl -O http://localhost:8081/repository/linux/simple/project/package.tar.gz

# Verify checksum
sha256sum package.tar.gz

## Local Development

```bash
# Start Nexus locally
make nexus-start

# Get admin password
make nexus-password

# Stop Nexus
make nexus-stop

# Run tests
make test
```

Nexus available at `http://localhost:8081`

## Project Structure

```
├── .github/workflows/          # GitHub Actions
│   ├── pypi-from-releases.yml  # PyPI generation
│   └── scan-python-release.yml # Security scanning
├── cmd/release-tool/main.go    # CLI entry point
├── internal/                   # Core packages
│   ├── cli/                    # Command handling
│   ├── downloader/             # File operations
│   └── generator/              # HTML generation
├── yara-rules/test-rules.yar   # Security rules
├── Makefile                    # Build tasks
├── docker-compose.yml          # Nexus setup
└── README.md
```

## URLs

After deployment:
- Root: `https://username.github.io/repo-name/`
- Linux: `https://username.github.io/repo-name/linux/simple/`
- macOS: `https://username.github.io/repo-name/mac/simple/`
- Windows: `https://username.github.io/repo-name/windows/simple/`

## Contributing

- Follow Go formatting (`gofmt`)
- Add tests for new features
- Update documentation

## License

Provided as-is for educational and production use.
