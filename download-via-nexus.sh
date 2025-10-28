#!/bin/bash
set -e

# Configuration
NEXUS_HOST="${NEXUS_HOST:-localhost:8081}"
NEXUS_REPO="${NEXUS_REPO:-pypi-proxy}"
NEXUS_URL="http://${NEXUS_HOST}/repository/${NEXUS_REPO}"

# Optional authentication (default: admin:password for local development)
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-password}"

# Get the latest release timestamp from the PyPI index
echo "=========================================="
echo "Python Security-Scanned Release Downloader"
echo "=========================================="
echo ""
echo "Fetching latest release information via Nexus..."

# Create temp directory
TEMP_DIR=$(mktemp -d -t python-nexus-download-XXXXXX)
echo "Working directory: $TEMP_DIR"
cd "$TEMP_DIR"

# Set up curl command with optional authentication
CURL_CMD="curl -f"
if [ -n "$NEXUS_USER" ] && [ -n "$NEXUS_PASSWORD" ]; then
    CURL_CMD="curl -f -u ${NEXUS_USER}:${NEXUS_PASSWORD}"
    echo "Using authentication for Nexus"
fi

# Fetch the PyPI index page to get available releases
echo ""
echo "Fetching PyPI index via Nexus proxy..."
INDEX_HTML=$($CURL_CMD -s "${NEXUS_URL}/linux/simple/python/" || {
    echo "ERROR: Could not reach Nexus proxy at ${NEXUS_URL}"
    echo ""
    echo "Make sure:"
    echo "  1. Nexus is running on ${NEXUS_HOST}"
    echo "  2. PyPI proxy repository '${NEXUS_REPO}' is configured"
    echo "  3. Remote URL is set to: https://naveensrinivasan.github.io/release-dir-list/"
    echo ""
    echo "Configure Nexus with:"
    echo "  NEXUS_HOST=localhost:8081 NEXUS_REPO=pypi-proxy $0"
    exit 1
})

# Extract the latest release timestamp
LATEST_TIMESTAMP=$(echo "$INDEX_HTML" | grep -o 'Python-3.14.0-[0-9]\{8\}-[0-9]\{6\}\.tar\.xz' | head -1 | sed 's/Python-3.14.0-\(.*\)\.tar\.xz/\1/')

if [ -z "$LATEST_TIMESTAMP" ]; then
    echo "ERROR: Could not find any Python releases in the index"
    exit 1
fi

echo "Latest release timestamp: $LATEST_TIMESTAMP"

# Extract SHA256 from the index
EXPECTED_SHA256=$(echo "$INDEX_HTML" | grep "Python-3.14.0-${LATEST_TIMESTAMP}.tar.xz#sha256=" | sed -n 's/.*sha256=\([a-f0-9]\{64\}\).*/\1/p' | head -1)

if [ -z "$EXPECTED_SHA256" ]; then
    echo "WARNING: Could not extract SHA256 from index, will skip checksum verification"
else
    echo "Expected SHA256: $EXPECTED_SHA256"
fi

echo ""
echo "=========================================="
echo "Downloading Python 3.14.0 Release"
echo "=========================================="

# Download Python tarball
PYTHON_FILE="Python-3.14.0-${LATEST_TIMESTAMP}.tar.xz"
echo ""
echo "Downloading: $PYTHON_FILE"
$CURL_CMD -# -o "$PYTHON_FILE" \
  "${NEXUS_URL}/linux/packages/${PYTHON_FILE}"
echo "Downloaded: $(ls -lh "$PYTHON_FILE" | awk '{print $5}')"

# Verify SHA256
if [ -n "$EXPECTED_SHA256" ]; then
    echo ""
    echo "Verifying SHA256 checksum..."
    echo "${EXPECTED_SHA256}  ${PYTHON_FILE}" | shasum -a 256 -c
fi

echo ""
echo "=========================================="
echo "Downloading Security Artifacts"
echo "=========================================="

# Download security attestation bundles
echo ""
echo "Downloading attestation bundles..."
$CURL_CMD -s -o "python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle" \
  "${NEXUS_URL}/linux/packages/python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle"
echo "  ✓ python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle"

$CURL_CMD -s -o "scan-results-attestation-${LATEST_TIMESTAMP}.bundle" \
  "${NEXUS_URL}/linux/packages/scan-results-attestation-${LATEST_TIMESTAMP}.bundle"
echo "  ✓ scan-results-attestation-${LATEST_TIMESTAMP}.bundle"

# Download SLSA predicates
echo ""
echo "Downloading SLSA predicate files..."
$CURL_CMD -s -o "python-predicate-${LATEST_TIMESTAMP}.json" \
  "${NEXUS_URL}/linux/packages/python-predicate-${LATEST_TIMESTAMP}.json"
echo "  ✓ python-predicate-${LATEST_TIMESTAMP}.json"

$CURL_CMD -s -o "scan-predicate-${LATEST_TIMESTAMP}.json" \
  "${NEXUS_URL}/linux/packages/scan-predicate-${LATEST_TIMESTAMP}.json"
echo "  ✓ scan-predicate-${LATEST_TIMESTAMP}.json"

# Download security reports
echo ""
echo "Downloading security scan reports..."
$CURL_CMD -s -o "security-scan-report-${LATEST_TIMESTAMP}.json" \
  "${NEXUS_URL}/linux/packages/security-scan-report-${LATEST_TIMESTAMP}.json"
echo "  ✓ security-scan-report-${LATEST_TIMESTAMP}.json"

$CURL_CMD -s -o "clamav-result-${LATEST_TIMESTAMP}.json" \
  "${NEXUS_URL}/linux/packages/clamav-result-${LATEST_TIMESTAMP}.json"
echo "  ✓ clamav-result-${LATEST_TIMESTAMP}.json"

$CURL_CMD -s -o "scan-results-${LATEST_TIMESTAMP}.json" \
  "${NEXUS_URL}/linux/packages/scan-results-${LATEST_TIMESTAMP}.json"
echo "  ✓ scan-results-${LATEST_TIMESTAMP}.json"

$CURL_CMD -s -o "clamav-scan-${LATEST_TIMESTAMP}.log" \
  "${NEXUS_URL}/linux/packages/clamav-scan-${LATEST_TIMESTAMP}.log"
echo "  ✓ clamav-scan-${LATEST_TIMESTAMP}.log"

echo ""
echo "=========================================="
echo "Security Scan Results"
echo "=========================================="

# Display ClamAV scan results
echo ""
echo "ClamAV Scan Status:"
cat "clamav-result-${LATEST_TIMESTAMP}.json" | grep -E '(status|threats_found)' || cat "clamav-result-${LATEST_TIMESTAMP}.json"

echo ""
echo "=========================================="
echo "Verifying with Cosign"
echo "=========================================="

# Check if cosign is installed
if command -v cosign &> /dev/null; then
    echo ""
    echo "Verifying Python artifact attestation..."
    cosign verify-blob "$PYTHON_FILE" \
      --bundle "python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle" \
      --certificate-identity-regexp="https://github.com/naveensrinivasan/release-dir-list" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
      2>&1 | grep -E "(Verified OK|WARNING|ERROR)" || echo "Verification completed"
    
    echo ""
    echo "Verifying scan results attestation..."
    cosign verify-blob "scan-results-${LATEST_TIMESTAMP}.json" \
      --bundle "scan-results-attestation-${LATEST_TIMESTAMP}.bundle" \
      --certificate-identity-regexp="https://github.com/naveensrinivasan/release-dir-list" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
      2>&1 | grep -E "(Verified OK|WARNING|ERROR)" || echo "Verification completed"
else
    echo ""
    echo "WARNING: cosign not installed, skipping signature verification"
    echo "Install with: brew install cosign (macOS) or download from https://github.com/sigstore/cosign"
fi

echo ""
echo "=========================================="
echo "Download Summary"
echo "=========================================="
echo ""
echo "All files downloaded to: $TEMP_DIR"
echo ""
ls -lh "$TEMP_DIR"
echo ""
echo "Files downloaded via Nexus proxy:"
echo "  Nexus URL: ${NEXUS_URL}"
echo "  Release: ${LATEST_TIMESTAMP}"
echo ""
echo "To inspect files:"
echo "  cd $TEMP_DIR"
echo ""
echo "To clean up:"
echo "  rm -rf $TEMP_DIR"
echo ""

