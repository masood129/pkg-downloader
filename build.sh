#!/bin/bash
# ============================================================
#  build.sh  –  Helper to build the Docker image for a
#               specific distribution and version
# ============================================================
set -euo pipefail

DISTRO="${1:-ubuntu}"
DISTRO_VERSION="${2:-24.04}"
TAG="pkg-downloader:${DISTRO}-${DISTRO_VERSION}"

echo "🔨 Building image: ${TAG}"
echo "   Distribution: ${DISTRO}:${DISTRO_VERSION}"
echo ""

docker build \
    --network=host \
    --build-arg DISTRO="${DISTRO}" \
    --build-arg DISTRO_VERSION="${DISTRO_VERSION}" \
    -t "${TAG}" \
    -t pkg-downloader:latest \
    "$(dirname "$0")"

echo ""
echo "✅ Image built successfully: ${TAG}"
echo ""
echo "Usage examples:"
echo "  docker run --rm -v \$(pwd)/output:/output ${TAG} -p curl"
echo "  docker run --rm -v \$(pwd)/output:/output ${TAG} -p nginx -v 1.24.0-2"
echo "  docker run --rm -v \$(pwd)/output:/output ${TAG} -p vim --include-recommends"
