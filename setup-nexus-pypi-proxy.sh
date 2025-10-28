#!/bin/bash
set -e

# Configuration
NEXUS_HOST="${NEXUS_HOST:-localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-password}"
REPO_NAME="${REPO_NAME:-pypi-proxy}"
REMOTE_URL="https://naveensrinivasan.com/release-dir-list"

echo "=========================================="
echo "Nexus PyPI Proxy Repository Setup"
echo "=========================================="
echo ""
echo "Nexus URL: http://${NEXUS_HOST}"
echo "Repository: ${REPO_NAME}"
echo "Remote URL: ${REMOTE_URL}"
echo ""

# Check if Nexus is accessible
echo "Checking Nexus connection..."
if ! curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "http://${NEXUS_HOST}/service/rest/v1/status" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to Nexus at http://${NEXUS_HOST}"
    echo ""
    echo "Please check:"
    echo "  1. Nexus is running"
    echo "  2. Credentials are correct (current: ${NEXUS_USER}:${NEXUS_PASSWORD})"
    echo ""
    exit 1
fi
echo "✓ Nexus is accessible"

# Check if repository already exists
echo ""
echo "Checking if repository '${REPO_NAME}' exists..."
REPO_EXISTS=$(curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    "http://${NEXUS_HOST}/service/rest/v1/repositories" 2>/dev/null | \
    grep -c "\"name\":\"${REPO_NAME}\"" || echo "0")

if [ "$REPO_EXISTS" -gt 0 ]; then
    echo "✓ Repository '${REPO_NAME}' already exists"
    
    # Get repository details
    echo ""
    echo "Repository details:"
    curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
        "http://${NEXUS_HOST}/service/rest/v1/repositories/${REPO_NAME}" 2>/dev/null | \
        grep -E '"name"|"url"|"remoteUrl"' || echo "Could not fetch details"
    
    echo ""
    echo "To recreate the repository, delete it first in Nexus UI or via API"
    exit 0
fi

echo "Repository '${REPO_NAME}' does not exist, creating..."

# Check if repository with this name already exists (different type)
echo "Checking for existing repository with same name..."
EXISTING=$(curl -s -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    "http://${NEXUS_HOST}/service/rest/v1/repositories" 2>/dev/null | \
    grep -o "\"name\":\"${REPO_NAME}\"" || echo "")

if [ -n "$EXISTING" ]; then
    echo "Repository '${REPO_NAME}' exists, deleting it first..."
    curl -s -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
        -X DELETE \
        "http://${NEXUS_HOST}/service/rest/v1/repositories/${REPO_NAME}" 2>/dev/null || true
    sleep 2
fi

# Create PyPI proxy repository
echo ""
echo "Creating PyPI proxy repository..."

PAYLOAD=$(cat <<EOF
{
  "name": "${REPO_NAME}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": false
  },
  "proxy": {
    "remoteUrl": "${REMOTE_URL}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "pypi": {
    "removeQuarantined": false
  }
}
EOF
)

HTTP_RESPONSE=$(curl -s -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    -w "\nHTTP_CODE:%{http_code}" \
    "http://${NEXUS_HOST}/service/rest/v1/repositories/pypi/proxy" 2>&1)

HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Repository created successfully!"
else
    echo "ERROR: Failed to create repository (HTTP ${HTTP_CODE})"
    echo ""
    echo "Response:"
    echo "$HTTP_RESPONSE" | grep -v "HTTP_CODE:"
    echo ""
    echo "Manual setup instructions:"
    echo "  1. Open Nexus UI: http://${NEXUS_HOST}"
    echo "  2. Login with: ${NEXUS_USER}/${NEXUS_PASSWORD}"
    echo "  3. Go to: Settings → Repositories → Create repository"
    echo "  4. Select: pypi (proxy)"
    echo "  5. Set Name: ${REPO_NAME}"
    echo "  6. Set Remote URL: ${REMOTE_URL}/"
    echo "  7. Click: Create repository"
    exit 1
fi

# Verify repository is accessible
echo ""
echo "Verifying repository access..."
sleep 3

TEST_SIMPLE_INDEX="http://${NEXUS_HOST}/repository/${REPO_NAME}/simple/"
TEST_PYTHON_INDEX="http://${NEXUS_HOST}/repository/${REPO_NAME}/simple/python/"

echo "Testing PyPI Simple Index: ${TEST_SIMPLE_INDEX}"
if curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_SIMPLE_INDEX}" 2>/dev/null | grep -q "python"; then
    echo "✓ PyPI Simple Index is accessible!"
    
    echo ""
    echo "Testing python package index: ${TEST_PYTHON_INDEX}"
    if curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_PYTHON_INDEX}" 2>/dev/null | grep -q "Python-3.14.0"; then
        RELEASE_COUNT=$(curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_PYTHON_INDEX}" 2>/dev/null | grep -c "<h2>Release:" || echo "0")
        echo "✓ Python packages accessible! Found ${RELEASE_COUNT} releases"
    else
        echo "⚠ Python package index accessible but no releases found yet (may need to wait)"
    fi
else
    echo "WARNING: Repository created but not yet accessible"
    echo "This may take a few moments for Nexus to initialize"
    echo "Try: curl -u ${NEXUS_USER}:${NEXUS_PASSWORD} ${TEST_SIMPLE_INDEX}"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "PyPI Proxy Repository: ${REPO_NAME}"
echo "Base URL: http://${NEXUS_HOST}/repository/${REPO_NAME}/"
echo "Simple Index: http://${NEXUS_HOST}/repository/${REPO_NAME}/simple/"
echo "Python Index: http://${NEXUS_HOST}/repository/${REPO_NAME}/simple/python/"
echo ""
echo "Remote proxying from: ${REMOTE_URL}"
echo ""
echo "Download Python releases via Nexus:"
echo "  NEXUS_REPO=${REPO_NAME} ./download-via-nexus.sh"
echo ""
echo "Or use pip with Nexus:"
echo "  pip install --index-url http://${NEXUS_USER}:${NEXUS_PASSWORD}@${NEXUS_HOST}/repository/${REPO_NAME}/simple python==3.14.0"
echo ""

