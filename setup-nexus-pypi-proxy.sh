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

# Create PyPI proxy repository
echo ""
echo "Creating PyPI proxy repository..."

PAYLOAD=$(cat <<EOF
{
  "name": "${REPO_NAME}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "${REMOTE_URL}/",
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
    "removeQuarantined": true
  }
}
EOF
)

HTTP_CODE=$(curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    -w "%{http_code}" \
    -o /tmp/nexus-create-response.txt \
    "http://${NEXUS_HOST}/service/rest/v1/repositories/pypi/proxy" 2>&1 || echo "000")

if [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Repository created successfully!"
else
    echo "ERROR: Failed to create repository (HTTP ${HTTP_CODE})"
    echo ""
    echo "Response:"
    cat /tmp/nexus-create-response.txt 2>/dev/null || echo "No response"
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
sleep 2

TEST_URL="http://${NEXUS_HOST}/repository/${REPO_NAME}/linux/simple/python/"
echo "Testing: ${TEST_URL}"

if curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_URL}" > /dev/null 2>&1; then
    echo "✓ Repository is accessible and proxying correctly!"
else
    echo "WARNING: Repository created but not yet accessible"
    echo "This may take a few moments for Nexus to initialize"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Repository URL: http://${NEXUS_HOST}/repository/${REPO_NAME}/"
echo "PyPI Index: http://${NEXUS_HOST}/repository/${REPO_NAME}/linux/simple/python/"
echo ""
echo "Test the repository:"
echo "  curl -u ${NEXUS_USER}:${NEXUS_PASSWORD} ${TEST_URL}"
echo ""
echo "Download Python releases via Nexus:"
echo "  ./download-via-nexus.sh"
echo ""

