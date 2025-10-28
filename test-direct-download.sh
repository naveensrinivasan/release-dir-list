#!/bin/bash
set -e

# Test direct download without Nexus to verify the PyPI repository works

echo "=========================================="
echo "Python Security-Scanned Release Downloader"
echo "Testing Direct Download (No Nexus)"
echo "=========================================="

# Direct URL to GitHub Pages
DIRECT_URL="https://naveensrinivasan.com/release-dir-list"

# Create temp directory
TEMP_DIR=$(mktemp -d -t python-direct-download-XXXXXX)
echo ""
echo "Working directory: $TEMP_DIR"
cd "$TEMP_DIR"

echo ""
echo "Fetching PyPI index directly from GitHub Pages..."
INDEX_HTML=$(curl -f -s "${DIRECT_URL}/linux/simple/python/")

# Extract the latest release timestamp
LATEST_TIMESTAMP=$(echo "$INDEX_HTML" | grep -o 'Python-3.14.0-[0-9]\{8\}-[0-9]\{6\}\.tar\.xz' | tail -1 | sed 's/Python-3.14.0-\(.*\)\.tar\.xz/\1/')

if [ -z "$LATEST_TIMESTAMP" ]; then
    echo "ERROR: Could not find any Python releases in the index"
    exit 1
fi

echo "Latest release timestamp: $LATEST_TIMESTAMP"

# Extract SHA256 from the index
EXPECTED_SHA256=$(echo "$INDEX_HTML" | grep "Python-3.14.0-${LATEST_TIMESTAMP}.tar.xz#sha256=" | sed -n 's/.*sha256=\([a-f0-9]\{64\}\).*/\1/p' | head -1)

if [ -z "$EXPECTED_SHA256" ]; then
    echo "WARNING: Could not extract SHA256 from index"
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
curl -# -o "$PYTHON_FILE" \
  "${DIRECT_URL}/linux/packages/${PYTHON_FILE}"
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
curl -s -o "python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle" \
  "${DIRECT_URL}/linux/packages/python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle"
echo "  ✓ python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle"

curl -s -o "scan-results-attestation-${LATEST_TIMESTAMP}.bundle" \
  "${DIRECT_URL}/linux/packages/scan-results-attestation-${LATEST_TIMESTAMP}.bundle"
echo "  ✓ scan-results-attestation-${LATEST_TIMESTAMP}.bundle"

# Download SLSA predicates
echo ""
echo "Downloading SLSA predicate files..."
curl -s -o "python-predicate-${LATEST_TIMESTAMP}.json" \
  "${DIRECT_URL}/linux/packages/python-predicate-${LATEST_TIMESTAMP}.json"
echo "  ✓ python-predicate-${LATEST_TIMESTAMP}.json"

curl -s -o "scan-predicate-${LATEST_TIMESTAMP}.json" \
  "${DIRECT_URL}/linux/packages/scan-predicate-${LATEST_TIMESTAMP}.json"
echo "  ✓ scan-predicate-${LATEST_TIMESTAMP}.json"

# Download security reports
echo ""
echo "Downloading security scan reports..."
curl -s -o "security-scan-report-${LATEST_TIMESTAMP}.json" \
  "${DIRECT_URL}/linux/packages/security-scan-report-${LATEST_TIMESTAMP}.json"
echo "  ✓ security-scan-report-${LATEST_TIMESTAMP}.json"

curl -s -o "clamav-result-${LATEST_TIMESTAMP}.json" \
  "${DIRECT_URL}/linux/packages/clamav-result-${LATEST_TIMESTAMP}.json"
echo "  ✓ clamav-result-${LATEST_TIMESTAMP}.json"

curl -s -o "scan-results-${LATEST_TIMESTAMP}.json" \
  "${DIRECT_URL}/linux/packages/scan-results-${LATEST_TIMESTAMP}.json"
echo "  ✓ scan-results-${LATEST_TIMESTAMP}.json"

curl -s -o "clamav-scan-${LATEST_TIMESTAMP}.log" \
  "${DIRECT_URL}/linux/packages/clamav-scan-${LATEST_TIMESTAMP}.log"
echo "  ✓ clamav-scan-${LATEST_TIMESTAMP}.log"

echo ""
echo "=========================================="
echo "Security Scan Results"
echo "=========================================="

# Display ClamAV scan results
echo ""
echo "ClamAV Scan Status:"
cat "clamav-result-${LATEST_TIMESTAMP}.json" | python3 -m json.tool 2>/dev/null || cat "clamav-result-${LATEST_TIMESTAMP}.json"

echo ""
echo "=========================================="
echo "Verifying with Cosign"
echo "=========================================="

# Check if cosign is installed
if command -v cosign &> /dev/null; then
    echo ""
    echo "Verifying Python artifact attestation..."
    if cosign verify-blob "$PYTHON_FILE" \
      --bundle "python-3.14.0-attestation-${LATEST_TIMESTAMP}.bundle" \
      --certificate-identity-regexp="https://github.com/naveensrinivasan/release-dir-list" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" 2>&1; then
        echo "✓ Python artifact attestation verified successfully"
    fi
    
    echo ""
    echo "Verifying scan results attestation..."
    if cosign verify-blob "scan-results-${LATEST_TIMESTAMP}.json" \
      --bundle "scan-results-attestation-${LATEST_TIMESTAMP}.bundle" \
      --certificate-identity-regexp="https://github.com/naveensrinivasan/release-dir-list" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" 2>&1; then
        echo "✓ Scan results attestation verified successfully"
    fi
else
    echo ""
    echo "WARNING: cosign not installed, skipping signature verification"
    echo "Install with: brew install cosign (macOS)"
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
echo "Files downloaded directly from GitHub Pages:"
echo "  Source: ${DIRECT_URL}"
echo "  Release: ${LATEST_TIMESTAMP}"
echo ""
echo "To inspect files:"
echo "  cd $TEMP_DIR"
echo ""
echo "To clean up:"
echo "  rm -rf $TEMP_DIR"
echo ""
echo "=========================================="
echo "Next: Test with Nexus Proxy"
echo "=========================================="
echo ""
echo "1. Start Nexus (if using Docker):"
echo "   docker run -d -p 8081:8081 --name nexus sonatype/nexus3"
echo ""
echo "2. Configure PyPI Proxy Repository in Nexus:"
echo "   - Login: http://localhost:8081 (admin/admin123)"
echo "   - Create PyPI (proxy) repository named 'pypi-proxy'"
echo "   - Remote URL: ${DIRECT_URL}/"
echo ""
echo "3. Run Nexus download script:"
echo "   ./download-via-nexus.sh"
echo ""

