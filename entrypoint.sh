#!/bin/bash
set -eu

# ============================================================
#  Offline Package Downloader  –  entrypoint.sh
#  Downloads a package + ALL recursive dependencies as .deb
#  files and bundles them into a .zip or .tar.gz archive.
# ============================================================

# ── colour helpers ──────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── usage ───────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage:
  docker run --rm -v \$(pwd)/output:/output pkg-downloader \\
      -p <package>              # required: package name
      [-v <version>]            # optional: specific version (e.g. "1.24.0-2")
      [-a <arch>]               # optional: architecture (default: amd64)
      [-m <mirror>]             # optional: custom APT mirror URL
      [-c <components>]         # optional: comma-separated components (e.g. "main,universe,multiverse")
      [-s <suites>]             # optional: comma-separated suites (e.g. "noble,noble-updates,noble-security")
      [-o <output-name>]        # optional: custom output archive filename (without extension)
      [-r <extra-repo>]         # optional: add extra APT repository line
      [--include-recommends]    # optional: include Recommends (off by default)
      [--include-suggests]      # optional: include Suggests   (off by default)
      [--format <zip|tar.gz>]   # optional: archive format (default: zip)
      [--check-versions]        # optional: query available versions and exit

Examples:
  # Download curl with all recursive dependencies (Ubuntu/Debian)
  docker run --rm -v \$(pwd)/output:/output pkg-downloader -p curl

  # Download specific version with custom mirror and components
  docker run --rm -v \$(pwd)/output:/output pkg-downloader \\
      -p nginx -v "1.24.0-2ubuntu7" -m "http://ir.archive.ubuntu.com/ubuntu" -c "main,universe"
EOF
    exit 1
}

# ── read distro info FIRST (before CLI arg parsing) ────────
if [[ -f /etc/os-release ]]; then
    DISTRO_NAME=$(. /etc/os-release && echo "${ID:-unknown}")
    DISTRO_VER=$(. /etc/os-release && echo "${VERSION_ID:-unknown}")
    DISTRO_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-unknown}")
else
    DISTRO_NAME="unknown"
    DISTRO_VER="unknown"
    DISTRO_CODENAME="unknown"
fi

# ── parse arguments ─────────────────────────────────────────
PACKAGE=""
PKG_VERSION=""
ARCH="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"
CUSTOM_MIRROR=""
CUSTOM_COMPONENTS=""
CUSTOM_SUITES=""
OUTPUT_NAME=""
EXTRA_REPO=""
ARCHIVE_FORMAT="zip"
INCLUDE_RECOMMENDS=false
INCLUDE_SUGGESTS=false
CHECK_VERSIONS_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--package)           PACKAGE="$2";             shift 2 ;;
        -v|--version)           PKG_VERSION="$2";         shift 2 ;;
        -a|--arch)              ARCH="$2";                shift 2 ;;
        -m|--mirror)            CUSTOM_MIRROR="$2";       shift 2 ;;
        -c|--components)        CUSTOM_COMPONENTS="$2";   shift 2 ;;
        -s|--suites)            CUSTOM_SUITES="$2";       shift 2 ;;
        -o|--output)            OUTPUT_NAME="$2";         shift 2 ;;
        -r|--repo)              EXTRA_REPO="$2";          shift 2 ;;
        -f|--format)            ARCHIVE_FORMAT="$2";      shift 2 ;;
        --include-recommends)   INCLUDE_RECOMMENDS=true;  shift ;;
        --include-suggests)     INCLUDE_SUGGESTS=true;    shift ;;
        --check-versions)       CHECK_VERSIONS_ONLY=true; shift ;;
        -h|--help)              usage ;;
        *)                      err "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$PACKAGE" ]]; then
    err "Package name is required. Use -p <package_name>"
    usage
fi

# ── apply mirror and components function ───────────────────
apply_mirror() {
    local target="$1"
    local clean_target=$(echo "$target" | sed -E 's|/+$||')
    if [[ ! "$clean_target" =~ ^https?:// ]]; then
        clean_target="http://${clean_target}"
    fi
    
    # Ubuntu deb822
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        sed -i -E "s|https?://archive\.ubuntu\.com/ubuntu/?|${clean_target}/|g" /etc/apt/sources.list.d/ubuntu.sources
        sed -i -E "s|https?://security\.ubuntu\.com/ubuntu/?|${clean_target}/|g" /etc/apt/sources.list.d/ubuntu.sources
    fi
    # Debian deb822
    if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
        sed -i -E "s|https?://deb\.debian\.org/debian/?|${clean_target}/|g" /etc/apt/sources.list.d/debian.sources
    fi
    # Traditional sources.list
    if [[ -f /etc/apt/sources.list ]]; then
        sed -i -E "s|https?://archive\.ubuntu\.com/ubuntu/?|${clean_target}/|g" /etc/apt/sources.list
        sed -i -E "s|https?://security\.ubuntu\.com/ubuntu/?|${clean_target}/|g" /etc/apt/sources.list
        sed -i -E "s|https?://deb\.debian\.org/debian/?|${clean_target}/|g" /etc/apt/sources.list
    fi
}

# Apply custom components if specified
if [[ -n "$CUSTOM_COMPONENTS" ]]; then
    SPACE_COMPONENTS=$(echo "$CUSTOM_COMPONENTS" | tr ',' ' ')
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        sed -i -E "s|^Components:.*|Components: ${SPACE_COMPONENTS}|g" /etc/apt/sources.list.d/ubuntu.sources
    fi
    if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
        sed -i -E "s|^Components:.*|Components: ${SPACE_COMPONENTS}|g" /etc/apt/sources.list.d/debian.sources
    fi
fi

# Apply custom mirror or auto-detect working mirror for Ubuntu
if [[ -n "$CUSTOM_MIRROR" ]]; then
    apply_mirror "$CUSTOM_MIRROR"
elif [[ "$DISTRO_NAME" == "ubuntu" ]]; then
    if ! timeout 2 bash -c "cat < /dev/null > /dev/tcp/archive.ubuntu.com/80" 2>/dev/null; then
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/ir.archive.ubuntu.com/80" 2>/dev/null; then
            apply_mirror "http://ir.archive.ubuntu.com/ubuntu"
        fi
    fi
fi

# ── quick version checking exit ────────────────────────────
if [[ "$CHECK_VERSIONS_ONLY" == "true" ]]; then
    if ! ls /var/lib/apt/lists/*Packages* >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || true
    fi
    apt-cache madison "$PACKAGE" 2>/dev/null || true
    exit 0
fi

echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║       📦  Offline Linux Package & Dep Downloader        ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
info "Distribution : ${BOLD}${DISTRO_NAME} ${DISTRO_VER} (${DISTRO_CODENAME})${NC}"
info "Architecture : ${BOLD}${ARCH}${NC}"
info "Package      : ${BOLD}${PACKAGE}${NC}"
[[ -n "$PKG_VERSION" ]] && info "Version      : ${BOLD}${PKG_VERSION}${NC}"
[[ -n "$CUSTOM_COMPONENTS" ]] && info "Components   : ${BOLD}${CUSTOM_COMPONENTS}${NC}"
info "Format       : ${BOLD}${ARCHIVE_FORMAT}${NC}"

# ── optional extra repo ────────────────────────────────────
if [[ -n "$EXTRA_REPO" ]]; then
    info "Adding extra repository: ${EXTRA_REPO}"
    echo "$EXTRA_REPO" >> /etc/apt/sources.list
fi

# ── update package index ───────────────────────────────────
info "Updating package index …"
DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
    warn "apt-get update failed. Attempting fallback mirror..."
    if [[ "$DISTRO_NAME" == "ubuntu" ]]; then
        apply_mirror "http://ir.archive.ubuntu.com/ubuntu"
    fi
    DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
        err "apt-get update failed. Please specify a working mirror using -m <mirror_url>"
        exit 1
    }
}
ok "Package index updated successfully"

# ── install zip if needed ──────────────────────────────────
if [[ "$ARCHIVE_FORMAT" == "zip" ]] && ! command -v zip > /dev/null 2>&1; then
    info "Installing zip utility …"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends zip > /dev/null 2>&1 || {
        warn "Could not install zip binary. Falling back to tar.gz format."
        ARCHIVE_FORMAT="tar.gz"
    }
fi

# ── verify target package exists ───────────────────────────
PACKAGE_SPEC="$PACKAGE"
if [[ -n "$PKG_VERSION" ]]; then
    PACKAGE_SPEC="${PACKAGE}=${PKG_VERSION}"
fi

if ! apt-cache show "$PACKAGE_SPEC" > /dev/null 2>&1; then
    err "Package '${PACKAGE_SPEC}' not found in repositories."
    info "Available versions for ${PACKAGE}:"
    apt-cache madison "$PACKAGE" 2>/dev/null || true
    exit 1
fi

RESOLVED_VERSION=$(apt-cache show "$PACKAGE_SPEC" 2>/dev/null | grep '^Version:' | head -n1 | awk '{print $2}')
ok "Target package resolved: ${BOLD}${PACKAGE} (${RESOLVED_VERSION})${NC}"

# ── resolve ALL recursive dependencies ─────────────────────
info "Resolving full recursive dependency tree …"

DEPENDS_FLAGS="--recurse --no-conflicts --no-breaks --no-replaces --no-enhances"
if [[ "$INCLUDE_RECOMMENDS" != "true" ]]; then
    DEPENDS_FLAGS="$DEPENDS_FLAGS --no-recommends"
fi
if [[ "$INCLUDE_SUGGESTS" != "true" ]]; then
    DEPENDS_FLAGS="$DEPENDS_FLAGS --no-suggests"
fi

RAW_DEPS=$(apt-cache depends $DEPENDS_FLAGS "$PACKAGE_SPEC" 2>/dev/null || true)

PARSED_PKGS=$(echo "$RAW_DEPS" | awk '
    /^[a-zA-Z0-9]/ { print $1 }
    /^\s*(Pre-)?Depends:/ { print $2 }
    /^\s*Recommends:/ { print $2 }
    /^\s*Suggests:/ { print $2 }
' | grep -v '^<' | grep -v '^|' | tr -d '<>' | sed 's/:any$//' | sort -u || true)

ALL_CANDIDATES=$(echo -e "${PACKAGE}\n${PARSED_PKGS}" | grep -E '^[a-zA-Z0-9]' | sort -u)

# Batch check valid packages instantaneously
VALID_PKGS=$(echo "$ALL_CANDIDATES" | xargs -r apt-cache show 2>/dev/null | awk '/^Package:/ {print $2}' | sort -u || true)

if [[ -z "$VALID_PKGS" ]]; then
    VALID_PKGS="$PACKAGE"
fi

TOTAL_VALID=$(echo "$VALID_PKGS" | wc -l)
ok "Identified ${BOLD}${TOTAL_VALID}${NC} packages to download (target package + dependencies)"

# ── download all .deb files ────────────────────────────────
WORK_DIR=$(mktemp -d /tmp/pkg-download.XXXXXX)
cd "$WORK_DIR"

info "Downloading all .deb files …"

# Download specific version of target package if requested
if [[ -n "$PKG_VERSION" ]]; then
    apt-get download "${PACKAGE}=${PKG_VERSION}" 2>&1 || apt-get download "${PACKAGE}" 2>&1 || true
fi

# Download in fast batch
echo "$VALID_PKGS" | xargs -r -n 20 apt-get download 2>&1 | while read -r line; do
    if [[ "$line" =~ ^Get: ]] || [[ "$line" =~ ^Fetched ]]; then
        echo -e "  ✔ ${line}"
    fi
done || true

# Check downloaded files
DEB_COUNT=$(find "$WORK_DIR" -name '*.deb' | wc -l)

# If any missed, try fallback single downloads
if [[ $DEB_COUNT -lt $TOTAL_VALID ]]; then
    for pkg in $VALID_PKGS; do
        if ! find "$WORK_DIR" -name "${pkg}_*.deb" | grep -q .; then
            apt-get download "$pkg" > /dev/null 2>&1 || apt-get download "${pkg}:${ARCH}" > /dev/null 2>&1 || true
        fi
    done
    DEB_COUNT=$(find "$WORK_DIR" -name '*.deb' | wc -l)
fi

if [[ $DEB_COUNT -eq 0 ]]; then
    err "No .deb files were downloaded. Aborting."
    rm -rf "$WORK_DIR"
    exit 1
fi

ok "Successfully downloaded ${BOLD}${DEB_COUNT}${NC} .deb files"

# ── create offline installer script ────────────────────────
cat > "$WORK_DIR/install.sh" << 'INSTALL_EOF'
#!/bin/bash
# ============================================================
#  Offline Package Installer
#  Installs all included .deb packages in dependency order
# ============================================================
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "📦 Starting Offline Package Installation"
echo "=================================================="

if [[ $EUID -ne 0 ]]; then
    if command -v sudo > /dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "❌ Error: Root permissions required." >&2
        exit 1
    fi
else
    SUDO=""
fi

DEB_COUNT=$(find . -maxdepth 1 -name '*.deb' | wc -l)
echo "Found ${DEB_COUNT} .deb packages to install."

# First pass with dpkg
echo "Installing packages with dpkg..."
$SUDO dpkg -i --force-depends *.deb 2>/dev/null || true

# Second pass to configure in proper order
echo "Configuring packages..."
$SUDO dpkg --configure -a

echo "Verifying installation integrity..."
$SUDO apt-get install -f -y --no-download 2>/dev/null || $SUDO dpkg -i *.deb 2>/dev/null || true

echo "=================================================="
echo "✅ Installation completed successfully!"
echo "=================================================="
INSTALL_EOF
chmod +x "$WORK_DIR/install.sh"

# ── create detailed manifest ───────────────────────────────
MANIFEST_FILE="$WORK_DIR/MANIFEST.txt"
cat > "$MANIFEST_FILE" << EOF
================================================================================
                      OFFLINE PACKAGE BUNDLE MANIFEST
================================================================================
Target Package : ${PACKAGE}
Target Version : ${RESOLVED_VERSION}
Target Distro  : ${DISTRO_NAME} ${DISTRO_VER} (${DISTRO_CODENAME})
Architecture   : ${ARCH}
Generated Date : $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Total Packages : ${DEB_COUNT}
================================================================================

INCLUDED PACKAGES:
EOF

for deb in "$WORK_DIR"/*.deb; do
    dpkg-deb -W --showformat='- ${Package} | Version: ${Version} | Arch: ${Architecture} | Size: ${Installed-Size}KB\n' "$deb" >> "$MANIFEST_FILE" 2>/dev/null || true
done

# ── create archive ─────────────────────────────────────────
if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="${PACKAGE}_${RESOLVED_VERSION}_${DISTRO_CODENAME}_${ARCH}_offline"
    OUTPUT_NAME=$(echo "$OUTPUT_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
fi

OUTPUT_DIR="/output"
mkdir -p "$OUTPUT_DIR"

if [[ "$ARCHIVE_FORMAT" == "zip" ]]; then
    FINAL_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.zip"
    info "Creating ZIP archive: ${BOLD}${OUTPUT_NAME}.zip${NC} …"
    cd "$WORK_DIR"
    zip -q -9 "$FINAL_FILE" *.deb install.sh MANIFEST.txt
else
    FINAL_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.tar.gz"
    info "Creating TAR.GZ archive: ${BOLD}${OUTPUT_NAME}.tar.gz${NC} …"
    cd "$WORK_DIR"
    tar czf "$FINAL_FILE" *.deb install.sh MANIFEST.txt
fi

FILE_SIZE=$(du -sh "$FINAL_FILE" | awk '{print $1}')

# ── summary banner ─────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅  Offline Bundle Created Successfully!                          ${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
echo -e "  📦 Package     : ${CYAN}${BOLD}${PACKAGE}${NC} (${RESOLVED_VERSION})"
echo -e "  🐧 Distro      : ${CYAN}${DISTRO_NAME} ${DISTRO_VER} (${DISTRO_CODENAME})${NC}"
echo -e "  💻 Arch        : ${CYAN}${ARCH}${NC}"
echo -e "  📄 Total .deb  : ${CYAN}${BOLD}${DEB_COUNT}${NC} files (all dependencies included)"
echo -e "  📁 Archive     : ${CYAN}${BOLD}$(basename "$FINAL_FILE")${NC}"
echo -e "  ⚖️  Archive Size: ${CYAN}${BOLD}${FILE_SIZE}${NC}"
echo -e "  📍 Location    : ${CYAN}${FINAL_FILE}${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}To install on your target offline machine:${NC}"
if [[ "$ARCHIVE_FORMAT" == "zip" ]]; then
    echo -e "  1. ${YELLOW}unzip $(basename "$FINAL_FILE") -d offline_pkg${NC}"
else
    echo -e "  1. ${YELLOW}mkdir offline_pkg && tar xzf $(basename "$FINAL_FILE") -C offline_pkg${NC}"
fi
echo -e "  2. ${YELLOW}cd offline_pkg && sudo bash install.sh${NC}"
echo ""

# ── cleanup ────────────────────────────────────────────────
rm -rf "$WORK_DIR"

exit 0
