# ============================================================
#  Offline Package Downloader
#  Supports: Ubuntu, Debian
#
#  No network needed at build time — only at run time.
#  Uses tar/gzip (built-in) so nothing extra needs installing.
# ============================================================

ARG DISTRO=ubuntu
ARG DISTRO_VERSION=24.04

FROM ${DISTRO}:${DISTRO_VERSION}

LABEL maintainer="pkg-downloader"
LABEL description="Downloads Linux packages with all dependencies for offline installation"

# Copy entrypoint script — no apt-get install needed at build time
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Output volume
VOLUME ["/output"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
