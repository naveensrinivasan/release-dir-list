# Security-Scanned Python Releases with PyPI Repository

This repository provides Python releases that have been scanned for malware, attested with Sigstore, and distributed through a PyPI-compatible repository. Organizations can proxy these releases through Nexus Repository Manager to enforce security validation before internal distribution.

## What This Repository Does

We automate the complete security validation pipeline for Python releases:

1. Download Python from the official python.org source
2. Scan with ClamAV malware scanner
3. Create Sigstore attestations with SLSA provenance
4. Publish to GitHub Releases with security reports
5. Host on GitHub Pages as a PyPI Simple repository
6. Enable Nexus proxy access for enterprise environments

Every Python release includes malware scan results, SHA256 checksums, and cryptographically signed attestations that can be independently verified.

## Why This Exists

Organizations need to validate software before distributing it internally. This repository:

- Provides a complete audit trail from source to distribution
- Enables security teams to verify malware scans and attestations
- Allows enterprises to proxy vetted Python releases through Nexus
- Maintains cryptographic proof of the security validation process
- Automates what would otherwise be manual security checks

## How It Works

### The Security Pipeline

**Step 1: Download**
Python 3.14.0 is downloaded from https://www.python.org/ftp/python/3.14.0/Python-3.14.0.tar.xz and its SHA256 checksum is calculated.

**Step 2: Malware Scan**
ClamAV (official Cisco Talos Docker image) scans the tarball. The scan must pass with zero threats detected before proceeding.

**Step 3: Sigstore Attestation**
Two attestations are created using Sigstore's keyless signing:
- Python executable attestation with SLSA provenance tracking the source
- Security scan results attestation documenting the ClamAV status

Both attestations are recorded in the Rekor transparency log for independent verification.

**Step 4: GitHub Release**
All artifacts are published to a GitHub Release:
- Python tarball
- Security scan report (JSON)
- Attestation bundles
- SLSA provenance predicates
- Scan logs

**Step 5: PyPI Repository**
Files are deployed to GitHub Pages in PyPI Simple format with relative URLs, enabling Nexus to proxy all artifacts from a single domain.

## Verification Example

Here's what we verified in the latest release:

**Python 3.14.0 Linux**
- File: Python-3.14.0.tar.xz
- Size: 23 MB
- SHA256: `2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9`

**ClamAV Scan**
- Status: CLEAN
- Threats found: 0
- Exit code: 0
- Scanner: clamav/clamav:stable (Docker)

**Sigstore Verification**
Both attestations verified successfully using cosign:
```
Verified OK
```

**Nexus Download**
Downloaded through local Nexus proxy at 187 MB/s with SHA256 verification.

## Using the PyPI Repository

### For Organizations with Nexus

Configure a PyPI proxy repository in Nexus:

**Repository Settings:**
- Name: `linux` (or your preferred name)
- Type: PyPI (Proxy)
- Remote URL: `https://naveensrinivasan.github.io/release-dir-list/linux/`
- Layout Policy: Permissive

Note: Nexus automatically appends `/simple/` to the URL.

**What Gets Proxied:**
When developers request Python from your Nexus repository, Nexus will:
1. Query the PyPI Simple index
2. Download the Python tarball from GitHub Pages
3. Cache it locally
4. Also proxy security reports and attestation bundles
5. Serve subsequent requests from cache

**Accessing Security Artifacts:**
All security artifacts are available through the same Nexus repository:
- Security reports at `/packages/python/scan/security-scan-report.json`
- Attestation bundles at `/packages/python/3.14.0/python-3.14.0-attestation.bundle`
- SLSA predicates at `/packages/python/predicate/python-predicate.json`

### For Direct Use

**PyPI Repository Index:**
https://naveensrinivasan.github.io/release-dir-list/linux/simple/python/

**Direct Downloads:**
All files are hosted on GitHub Pages under the `/packages/` directory:
- Python tarball: `https://naveensrinivasan.github.io/release-dir-list/linux/packages/Python-3.14.0.tar.xz`
- Security report: `https://naveensrinivasan.github.io/release-dir-list/linux/packages/security-scan-report.json`
- Attestation bundle: `https://naveensrinivasan.github.io/release-dir-list/linux/packages/python-3.14.0-attestation.bundle`

## Validating Downloads

### Download and Verify SHA256

```bash
# Download Python tarball
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/Python-3.14.0.tar.xz

# Verify checksum
sha256sum Python-3.14.0.tar.xz
```

**Expected output:**
```
2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9  Python-3.14.0.tar.xz
```

### Download Security Reports

```bash
# Get the security scan report
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/security-scan-report.json

# View ClamAV results
cat security-scan-report.json | jq '.security_scan_report.scan_results.clamav_scan'
```

**Expected output:**
```json
{
  "status": "clean",
  "file": "Python-3.14.0.tar.xz",
  "threats_found": 0,
  "exit_code": 0
}
```

### Verify Sigstore Attestations

**Install cosign:**
```bash
# macOS
brew install cosign

# Linux
wget https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
```

**Download attestation bundles:**
```bash
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/python-3.14.0-attestation.bundle
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/scan-results-attestation.bundle
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/scan-results.json
```

**Verify Python executable attestation:**
```bash
cosign verify-blob-attestation \
  --bundle python-3.14.0-attestation.bundle \
  --type slsaprovenance \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  Python-3.14.0.tar.xz
```

**Expected output:**
```
Verified OK
```

**Verify scan results attestation:**
```bash
cosign verify-blob-attestation \
  --bundle scan-results-attestation.bundle \
  --type slsaprovenance \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  scan-results.json
```

**Expected output:**
```
Verified OK
```

### Examine SLSA Provenance

Download and inspect the provenance metadata:

```bash
# Download provenance predicates
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/python-predicate.json
curl -LO https://naveensrinivasan.github.io/release-dir-list/linux/packages/scan-predicate.json

# View Python download provenance
cat python-predicate.json | jq .
```

The provenance includes:
- Source URL (python.org)
- SHA256 checksum
- GitHub Actions workflow details
- Build timestamps
- Repository information

## Security Features

### Source Verification

Every Python release includes:
- Original source URL from python.org
- SHA256 checksum calculated after download
- SLSA provenance tracking the download origin

### Malware Scanning

**Scanner:** ClamAV (official Cisco Talos Docker image)
- Docker image: `clamav/clamav:stable`
- Provider: Cisco Talos Intelligence Group
- Database: Updated automatically by the scanner
- Method: Full recursive scan

The workflow fails immediately if any threats are detected.

### Sigstore Attestation

**What is Sigstore?**
Sigstore provides keyless signing using short-lived certificates from an OpenID Connect (OIDC) identity provider. Signatures are recorded in a public transparency log (Rekor) for independent verification.

**Our Attestations:**
1. Python Executable Attestation
   - Type: SLSA Provenance v0.2
   - Builder: GitHub Actions runner
   - Certificate: Issued by GitHub's OIDC provider
   - Transparency: Recorded in Rekor log

2. Security Scan Results Attestation
   - Type: SLSA Provenance v0.2
   - Contains: ClamAV scan status
   - Builder: GitHub Actions runner
   - Transparency: Recorded in Rekor log

### SLSA Provenance

SLSA (Supply-chain Levels for Software Artifacts) provenance documents the build process. Our provenance includes:

**For Python Download:**
- Build type: python-download
- External parameters: Source URL, SHA256
- Internal parameters: Repository, workflow, run ID
- Build metadata: Start/finish timestamps

**For Security Scan:**
- Build type: security-scan
- External parameters: Target file, source, SHA256
- Internal parameters: ClamAV status, workflow details
- Build metadata: Scan timestamps

### Transparency Log

All attestations are recorded in Sigstore's Rekor transparency log. This provides:
- Immutable record of when attestations were created
- Public verification without requiring our keys
- Proof that attestations existed at a specific time
- Independent audit trail

### Complete Audit Trail

For each Python release, you can verify:
1. Source authenticity (python.org + SHA256)
2. Malware scan results (ClamAV logs)
3. Attestation validity (cosign verification)
4. SLSA provenance (JSON metadata)
5. Transparency log entry (Rekor)
6. Workflow execution (GitHub Actions logs)

## Live Examples

View the actual implementation:

**Latest Workflow Run:**
https://github.com/naveensrinivasan/release-dir-list/actions/runs/18764724047

See the complete execution including ClamAV scan, Sigstore attestation, and deployment.

**Latest Release:**
https://github.com/naveensrinivasan/release-dir-list/releases/tag/python-3.14.0-scan-20251023-232529

Download all artifacts including:
- Python-3.14.0.tar.xz (23 MB)
- security-scan-report.json
- python-3.14.0-attestation.bundle
- scan-results-attestation.bundle
- python-predicate.json
- scan-predicate.json
- clamav-scan.log
- clamav-result.json
- scan-results.json

**PyPI Repository Webpage:**
https://naveensrinivasan.github.io/release-dir-list/

Browse the hosted repository structure.

**Python Package Index:**
https://naveensrinivasan.github.io/release-dir-list/linux/simple/python/

View the PyPI Simple index with links to all artifacts.

## Nexus Proxy Test Results

We verified the complete workflow through Nexus Repository Manager:

**Configuration:**
- Repository Type: PyPI (Proxy)
- Remote URL: `https://naveensrinivasan.github.io/release-dir-list/linux/`

**Download Test:**
```bash
curl -LO http://localhost:8081/repository/linux/packages/python/3.14.0/Python-3.14.0.tar.xz
```

**Results:**
- Download speed: 187 MB/s (cached by Nexus)
- File size: 23 MB
- SHA256: Verified match
- Security reports: Accessible through same proxy
- Attestation bundles: Available through Nexus

## Running the Workflow

The workflow runs automatically, but you can trigger it manually:

1. Go to the Actions tab in this repository
2. Select "Python Security Scan, Attest, and Release"
3. Click "Run workflow"
4. Wait approximately 1 minute for completion

Each run creates a unique timestamped release to avoid conflicts during testing.

## Download Scripts

Two simple scripts are provided for testing:

### Direct Download (No Nexus Required)
```bash
./test-direct-download.sh
```
Downloads directly from GitHub Pages and verifies all security artifacts.

### Nexus Proxy Download
```bash
./download-via-nexus.sh
```
Downloads through a configured Nexus Raw Proxy repository. Requires:
- Nexus running on localhost:8081
- Raw proxy repository named `python-security-proxy`
- Remote URL: `https://naveensrinivasan.com/release-dir-list/`

Both scripts create isolated temporary directories and clean up automatically.

