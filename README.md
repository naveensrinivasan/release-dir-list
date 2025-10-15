# Release Directory List

A tool for generating PyPI Simple repository structures from GitHub releases, designed to work with Nexus Repository Manager as a proxy.

## Overview

This project automatically generates PyPI-compatible repository indexes from GitHub release assets. The indexes are deployed to GitHub Pages and can be proxied through Nexus Repository Manager, allowing you to cache and serve release artifacts through your own infrastructure.

The system supports separate repositories for Linux, macOS, and Windows platforms, with automatic SHA256 checksum generation and verification.

## How It Works

1. **GitHub Releases**: Upload release binaries to GitHub releases
2. **Automated Generation**: A GitHub Actions workflow fetches the releases and generates PyPI Simple HTML indexes
3. **GitHub Pages**: The generated indexes are deployed to GitHub Pages
4. **Nexus Proxy**: Nexus proxies requests through the GitHub Pages indexes and caches the actual binaries from GitHub releases

## Architecture

```
GitHub Releases (binaries)
    |
    v
GitHub Actions (generates indexes)
    |
    v
GitHub Pages (hosts indexes)
    |
    v
Nexus Repository Manager (proxies and caches)
    |
    v
End Users
```

## Features

- Automatic PyPI Simple repository generation from GitHub releases
- Separate repositories for Linux, macOS, and Windows
- SHA256 checksum calculation and verification
- Automated deployment via GitHub Actions
- Compatible with Nexus Repository Manager
- CLI tool for manual generation and testing

## Prerequisites

- Go 1.21 or later
- GitHub repository with releases
- GitHub Pages enabled
- Nexus Repository Manager (for proxying)

## Installation

### Building from Source

```bash
make build
```

This creates the `bin/release-tool` binary.

### Using the CLI Tool

Generate PyPI repositories from a release source:

```bash
./bin/release-tool generate \
  --url https://www.example.com/releases/ \
  --output releases \
  --project myproject \
  --log-level info
```

Options:
- `--url`: Source URL to fetch files from
- `--output`: Output directory for generated structure
- `--project`: Project name for PyPI repository
- `--log-level`: Logging level (debug, info, warn, error)

## GitHub Actions Workflow

The repository includes an automated workflow that:

1. Triggers on new releases
2. Downloads release assets
3. Calculates SHA256 checksums
4. Generates PyPI Simple HTML indexes
5. Deploys to GitHub Pages

The workflow runs automatically when you publish a new release, or can be triggered manually from the Actions tab.

## Security Scanning and Attestation Workflow

The repository includes a security scanning proof-of-concept workflow (`scan-python-release.yml`) that demonstrates secure software supply chain practices:

### Features

- **ClamAV Virus Scanning**: Uses official Cisco Talos ClamAV Docker image for malware detection
- **YARA Rule-Based Scanning**: Custom YARA rules for pattern-based threat detection
- **Sigstore Attestation**: Cryptographic attestation of both the scanned files and scan results
- **Structured JSON Logging**: All scan results and logs in JSON format
- **GitHub OIDC Integration**: Keyless signing using GitHub's identity tokens

### How It Works

1. **Download**: Fetches Python 3.14.0 executable from python.org
2. **Virus Scan**: ClamAV scans for known malware signatures
3. **Rule-Based Scan**: YARA applies custom rules for suspicious patterns
4. **Attestation**: Creates Sigstore attestations for both the executable and scan results
5. **Verification**: Validates attestations using Sigstore transparency logs

### Running the Security Scan

The security scan workflow can be triggered manually from the Actions tab:

1. Go to the **Actions** tab in your GitHub repository
2. Select **"Security Scan and Attestation POC"**
3. Click **"Run workflow"**

### Scan Results

Upon completion, the workflow uploads artifacts containing:

- **Comprehensive Security Report** (`security-scan-report-{run_id}.json`) - Single downloadable JSON file with all scan results, attestation details, and metadata
- Scan logs from ClamAV and YARA
- Structured JSON results
- Sigstore attestation bundles
- Verification proofs

### Security Features

- **Fails on Detection**: Workflow fails if malware or suspicious patterns are found
- **Official Tools**: Uses official ClamAV Docker image and native YARA installation
- **Transparency**: All attestations are logged to Sigstore's public transparency log
- **Keyless Signing**: No private keys required, uses GitHub OIDC tokens

## Nexus Repository Configuration

### Creating PyPI Proxy Repositories

For each platform (Linux, macOS, Windows), create a PyPI proxy repository in Nexus:

1. Navigate to Repository → Repositories → Create repository
2. Select "pypi (proxy)"
3. Configure:
   - **Name**: `linux`, `mac`, or `windows`
   - **Remote URL**: 
     - Linux: `https://your-username.github.io/your-repo/linux`
     - macOS: `https://your-username.github.io/your-repo/mac`
     - Windows: `https://your-username.github.io/your-repo/windows`
   - Note: Do not include `/simple/` in the URL - Nexus adds this automatically
4. Save

### Creating a Repository Group

To combine all platforms into a single endpoint:

1. Create a new "pypi (group)" repository
2. Add the Linux, macOS, and Windows proxy repositories as members
3. Users can now access all platforms through the group URL

### Testing the Configuration

Download a package through Nexus:

```bash
curl -O http://localhost:8081/repository/linux/packages/python/3.14.0/Python-3.14.0.tar.xz
```

Verify the checksum:

```bash
sha256sum Python-3.14.0.tar.xz
```

## Local Development

### Running Nexus Locally

The repository includes a Docker Compose configuration for local testing:

```bash
make nexus-start
```

Access Nexus at `http://localhost:8081`. Get the initial admin password:

```bash
make nexus-password
```

Stop Nexus:

```bash
make nexus-stop
```

### Running Tests

```bash
make test
```

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── pypi-from-releases.yml    # Automated PyPI generation
│       └── scan-python-release.yml   # Security scanning POC
├── cmd/
│   └── release-tool/
│       └── main.go                   # CLI entry point
├── internal/
│   ├── cli/                          # CLI commands
│   ├── downloader/                   # File downloader
│   └── generator/                    # HTML generator
├── yara-rules/
│   └── test-rules.yar                # YARA security rules
├── .gitignore
├── Makefile
├── docker-compose.yml                # Local Nexus setup
├── go.mod
├── go.sum
└── README.md
```

## PyPI Simple Repository Format

The generated structure follows the PyPI Simple Repository API (PEP 503):

```
/{platform}/simple/
├── index.html                        # Root index
└── {project}/
    └── index.html                    # Package index with download links
```

Each package index includes:
- Direct download URLs to GitHub release assets
- SHA256 checksums in URL fragments
- Compatible with pip and other PyPI clients

## GitHub Pages URLs

After deployment, your repositories will be available at:

- Root: `https://username.github.io/repository-name/`
- Linux: `https://username.github.io/repository-name/linux/simple/`
- macOS: `https://username.github.io/repository-name/mac/simple/`
- Windows: `https://username.github.io/repository-name/windows/simple/`

## Contributing

Contributions are welcome. Please ensure:

- Code follows Go standard formatting (`gofmt`)
- All tests pass
- New features include tests
- Documentation is updated

## License

This project is provided as-is for educational and production use.

## Troubleshooting

### Nexus returns 404

Ensure the remote URL does not include `/simple/` - Nexus adds this automatically.

### Checksums don't match

The workflow calculates checksums from the actual release assets. If checksums don't match, the release files may have been modified.

### GitHub Pages not updating

Check the Actions tab for workflow runs. Ensure GitHub Pages is configured to use GitHub Actions as the source.

## Further Reading

- [PyPI Simple Repository API (PEP 503)](https://peps.python.org/pep-0503/)
- [Nexus Repository Manager Documentation](https://help.sonatype.com/repomanager3)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
