#!/bin/bash
set -e

# Configuration
NEXUS_HOST="${NEXUS_HOST:-localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-password}"
REPO_NAME="${REPO_NAME:-python-security-proxy}"
REMOTE_URL="https://naveensrinivasan.com/release-dir-list"

echo "=========================================="
echo "Nexus Raw Proxy Repository Setup"
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
    exit 1
fi
echo "✓ Nexus is accessible"

# Check if repository already exists
echo ""
echo "Checking if repository '${REPO_NAME}' exists..."
REPO_CHECK=$(curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    "http://${NEXUS_HOST}/service/rest/v1/repositories" 2>/dev/null || echo "")

if echo "$REPO_CHECK" | grep -q "\"name\":\"${REPO_NAME}\""; then
    echo "Repository '${REPO_NAME}' already exists. Deleting..."
    curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
        -X DELETE \
        "http://${NEXUS_HOST}/service/rest/v1/repositories/${REPO_NAME}" 2>/dev/null || true
    sleep 2
fi

echo "Creating Raw proxy repository..."

# Create Raw proxy repository
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
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}
EOF
)

HTTP_CODE=$(curl -s -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    -w "%{http_code}" \
    -o /tmp/nexus-create-response.txt \
    "http://${NEXUS_HOST}/service/rest/v1/repositories/raw/proxy" 2>&1 | tail -1)

if [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Repository created successfully!"
else
    echo "ERROR: Failed to create repository (HTTP ${HTTP_CODE})"
    cat /tmp/nexus-create-response.txt 2>/dev/null
    exit 1
fi

# Verify repository is accessible
echo ""
echo "Verifying repository access..."
sleep 3

TEST_URL="http://${NEXUS_HOST}/repository/${REPO_NAME}/linux/simple/python/"
echo "Testing: ${TEST_URL}"

if curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_URL}" | grep -q "Python-3.14.0"; then
    echo "✓ Repository is accessible and proxying correctly!"
    
    # Count releases
    RELEASE_COUNT=$(curl -sf -u "${NEXUS_USER}:${NEXUS_PASSWORD}" "${TEST_URL}" | grep -c "<h2>Release:" || echo "0")
    echo "✓ Found ${RELEASE_COUNT} Python releases available through proxy"
else
    echo "WARNING: Repository created but content may take a moment to be available"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Repository URL: http://${NEXUS_HOST}/repository/${REPO_NAME}/"
echo "PyPI Index: ${TEST_URL}"
echo ""
echo "Test downloading:"
echo "  NEXUS_REPO=${REPO_NAME} ./download-via-nexus.sh"
echo ""

