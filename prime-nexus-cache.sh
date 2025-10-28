#!/bin/bash
# Prime Nexus cache by downloading all Python releases

NEXUS_URL="http://localhost:8081/repository/python-security-proxy"

echo "Fetching list of Python releases from Nexus..."
RELEASES=$(curl -s -u admin:password "${NEXUS_URL}/simple/python/" | grep -o 'Python-3.14.0-[0-9]\{8\}-[0-9]\{6\}\.tar\.xz' | sort -u)

echo "Found $(echo "$RELEASES" | wc -l | tr -d ' ') releases"
echo ""
echo "Priming Nexus cache (this will trigger downloads)..."

for file in $RELEASES; do
    echo "  Caching: $file"
    curl -s -u admin:password -I "${NEXUS_URL}/packages/${file}" > /dev/null
done

echo ""
echo "✓ Nexus cache primed!"
echo "All releases are now cached in Nexus blob storage"
echo ""
echo "Refresh the Nexus Browse UI to see all packages"
