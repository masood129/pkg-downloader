#!/bin/bash
# ============================================================
#  download.sh – All-in-one Host CLI for Offline Package Downloader
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
DISTRO="ubuntu"
DISTRO_RELEASE="24.04"
PACKAGE=""
PKG_VERSION=""
ARCH="amd64"
CUSTOM_MIRROR=""
CUSTOM_COMPONENTS=""
OUTPUT_NAME=""
FORMAT="zip"
JOB_ID="job-$$"
EXTRA_FLAGS=()

usage() {
    cat <<EOF
Usage:
  ./download.sh -p <package> [options]

Required:
  -p, --package <name>       Package name to download (e.g. nginx, curl, docker.io)

Options:
  -d, --distro <distro>      Target Linux distro: ubuntu (default) or debian
  -r, --release <release>    Target release version (e.g. 24.04, 22.04, 20.04, 12, 11) [default: 24.04]
  -v, --version <version>    Specific package version (optional, e.g. 1.24.0-2ubuntu7)
  -a, --arch <arch>          Target architecture: amd64 (default), arm64, armhf, etc.
  -m, --mirror <url>         Custom APT mirror URL (optional)
  -c, --components <list>    Comma-separated components (e.g. "main,universe,multiverse,restricted")
  -o, --output-dir <path>    Host output directory [default: ./output]
  -f, --format <zip|tar.gz>  Archive format: zip (default) or tar.gz
  --job-id <id>              Unique job identifier for container lifecycle management
  --include-recommends       Include recommended dependencies
  --include-suggests         Include suggested dependencies
  --rebuild                  Force rebuild Docker image before running
  -h, --help                 Show this help message

Examples:
  # 1. Download curl for Ubuntu 24.04 (Noble) with all recursive dependencies:
  ./download.sh -p curl

  # 2. Download nginx for Ubuntu 22.04 with main and universe components:
  ./download.sh -p nginx -d ubuntu -r 22.04 -c "main,universe"

  # 3. Download htop for Debian 12 (Bookworm):
  ./download.sh -p htop -d debian -r 12

  # 4. Download a specific version with Iranian mirror:
  ./download.sh -p nginx -d ubuntu -r 24.04 -v "1.24.0-2ubuntu7" -m "http://ir.archive.ubuntu.com/ubuntu"
EOF
    exit 1
}

REBUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--package)       PACKAGE="$2"; shift 2 ;;
        -d|--distro)        DISTRO="$2"; shift 2 ;;
        -r|--release)       DISTRO_RELEASE="$2"; shift 2 ;;
        -v|--version)       PKG_VERSION="$2"; shift 2 ;;
        -a|--arch)          ARCH="$2"; shift 2 ;;
        -m|--mirror)        CUSTOM_MIRROR="$2"; shift 2 ;;
        -c|--components)    CUSTOM_COMPONENTS="$2"; shift 2 ;;
        -o|--output-dir)    OUTPUT_DIR="$2"; shift 2 ;;
        -f|--format)        FORMAT="$2"; shift 2 ;;
        --job-id)           JOB_ID="$2"; shift 2 ;;
        --include-recommends) EXTRA_FLAGS+=("--include-recommends"); shift ;;
        --include-suggests)   EXTRA_FLAGS+=("--include-suggests"); shift ;;
        --rebuild)          REBUILD=true; shift ;;
        -h|--help)          usage ;;
        *)                  echo "Unknown argument: $1" >&2; usage ;;
    esac
done

if [[ -z "$PACKAGE" ]]; then
    echo "❌ Error: -p/--package is required." >&2
    usage
fi

# Ensure docker is available
if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Error: Docker is not installed or not in PATH." >&2
    exit 1
fi

CONTAINER_NAME="pkg-dl-${JOB_ID}"

# Trap signals to ensure container is stopped on exit or interrupt
cleanup_container() {
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup_container SIGINT SIGTERM EXIT

IMAGE_TAG="pkg-downloader:${DISTRO}-${DISTRO_RELEASE}"

# Check if image needs building
if [[ "$REBUILD" == "true" ]] || ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "🔨 Building Docker image for ${DISTRO}:${DISTRO_RELEASE} ..."
    docker build \
        --network=host \
        --build-arg DISTRO="${DISTRO}" \
        --build-arg DISTRO_VERSION="${DISTRO_RELEASE}" \
        -t "$IMAGE_TAG" \
        "$SCRIPT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

# Assemble container arguments
RUN_ARGS=(
    "-p" "$PACKAGE"
    "-a" "$ARCH"
    "-f" "$FORMAT"
)

if [[ -n "$PKG_VERSION" ]]; then
    RUN_ARGS+=("-v" "$PKG_VERSION")
fi
if [[ -n "$CUSTOM_MIRROR" ]]; then
    RUN_ARGS+=("-m" "$CUSTOM_MIRROR")
fi
if [[ -n "$CUSTOM_COMPONENTS" ]]; then
    RUN_ARGS+=("-c" "$CUSTOM_COMPONENTS")
fi
if [[ ${#EXTRA_FLAGS[@]} -gt 0 ]]; then
    RUN_ARGS+=("${EXTRA_FLAGS[@]}")
fi

echo "🚀 Running package downloader in container (${CONTAINER_NAME}) ..."
docker run --rm \
    --name "$CONTAINER_NAME" \
    --network=host \
    -v "${SCRIPT_DIR}/entrypoint.sh:/usr/local/bin/entrypoint.sh:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "$IMAGE_TAG" \
    "${RUN_ARGS[@]}"

echo "🎉 Done! Check your offline bundle in: ${OUTPUT_DIR}"
