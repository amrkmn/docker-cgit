# syntax=docker/dockerfile:1
ARG ALPINE_VERSION=3.22
ARG S6_OVERLAY_VERSION=3.2.1.0

# Build metadata
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG BUILD_DATE
ARG SOURCE_COMMIT
ARG SOURCE_VERSION

################################################################################
# Stage 1: Build cgit from source
################################################################################
FROM alpine:${ALPINE_VERSION} AS builder
ARG CGIT_GIT_URL=https://git.zx2c4.com/cgit
ARG CGIT_VERSION=master

# Install build dependencies
RUN apk add --no-cache \
    git \
    make \
    gcc \
    musl-dev \
    openssl-dev \
    zlib-dev \
    luajit-dev \
    gettext-dev \
    gettext

# To avoid conflict with musl: undeclared REG_STARTEND
ENV NO_REGEX=NeedsStartEnd

# Disable gettext support completely
ENV NO_GETTEXT=1

WORKDIR /opt/cgit-build

# Clone cgit and checkout version - optimize for cross-compilation
RUN git clone --depth 1 --single-branch ${CGIT_GIT_URL} . && \
    git checkout ${CGIT_VERSION} && \
    git submodule update --depth 1 --init --recursive

# Copy build configuration
COPY cgit_build.conf /opt/cgit-build/cgit.conf

# Build and install cgit with parallel jobs
RUN make -j$(nproc) && make install

################################################################################
# Stage 2: Runtime image
################################################################################
FROM alpine:${ALPINE_VERSION}
ARG S6_OVERLAY_VERSION

# Install runtime dependencies
RUN apk add --no-cache \
    # Core git functionality
    git \
    git-daemon \
    # Web server and FastCGI
    nginx \
    fcgiwrap \
    spawn-fcgi \
    # SSH server
    openssh-server \
    # Bash for helper scripts
    bash \
    # User management for PUID/PGID
    shadow \
    # Python for README rendering
    python3 \
    py3-markdown \
    py3-pygments \
    # For downloading Chroma
    curl

# Use system rst2html instead of pip
RUN ln -sf python3 /usr/bin/python

# Download and install Chroma syntax highlighter (supports Svelte, Astro, SolidJS, etc.)
# Use architecture-specific binary based on TARGETPLATFORM
ARG TARGETPLATFORM
ARG CHROMA_VERSION=2.14.0

RUN ARCH=$(case "$TARGETPLATFORM" in \
        "linux/amd64") echo "amd64" ;; \
        "linux/arm64") echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    echo "Downloading Chroma v${CHROMA_VERSION} for ${ARCH}" && \
    curl -fsSL "https://github.com/alecthomas/chroma/releases/download/v${CHROMA_VERSION}/chroma-${CHROMA_VERSION}-linux-${ARCH}.tar.gz" -o /tmp/chroma.tar.gz && \
    ls -lh /tmp/chroma.tar.gz && \
    tar -xz -C /usr/local/bin -f /tmp/chroma.tar.gz && \
    chmod +x /usr/local/bin/chroma && \
    /usr/local/bin/chroma --version && \
    rm /tmp/chroma.tar.gz

# Download and install s6-overlay
# Use architecture-specific binary based on TARGETPLATFORM
ARG TARGETPLATFORM
ARG S6_OVERLAY_VERSION

# Cache architecture-specific downloads separately
RUN ARCH=$(case "$TARGETPLATFORM" in \
        "linux/amd64") echo "x86_64" ;; \
        "linux/arm64") echo "aarch64" ;; \
        *) echo "x86_64" ;; \
    esac) && \
    echo "Downloading s6-overlay for ${ARCH}" && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" -o /tmp/s6-overlay-noarch.tar.xz && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz" -o /tmp/s6-overlay-${ARCH}.tar.xz && \
    ls -lh /tmp/s6-overlay-*.tar.xz

RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${ARCH}.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

# Copy cgit from builder stage
COPY --from=builder /opt/cgit /opt/cgit

# Create entrypoint wrapper for auto-config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create git user and group (UID/GID 1000)
RUN addgroup -g 1000 git && \
    adduser -D -h /opt/cgit/data/repositories -u 1000 -G git -s /bin/sh git && \
    echo 'git:temp123' | chpasswd

# Add nginx to git group for read access to repositories
RUN addgroup nginx git

# Create /opt/cgit/data directory structure
RUN mkdir -p /opt/cgit/data/repositories /opt/cgit/data/cache /opt/cgit/data/ssh /opt/cgit/bin && \
    mkdir -p /run/nginx /var/log/nginx && \
    touch /opt/cgit/data/ssh/authorized_keys && \
    chmod 700 /opt/cgit/data/ssh && \
    chmod 600 /opt/cgit/data/ssh/authorized_keys && \
    chown -R git:git /opt/cgit/data/ssh /opt/cgit/data/repositories && \
    chown -R nginx:nginx /opt/cgit/data/cache && \
    chmod 755 /opt/cgit/data/repositories /opt/cgit/data/cache /opt/cgit/data/ssh

# Remove default nginx config that conflicts before copying our config
RUN rm -f /etc/nginx/http.d/default.conf

# Copy configuration files
COPY config/cgitrc /opt/cgit/cgitrc
COPY config/cgit-dark.css /opt/cgit/app/cgit-dark.css
COPY config/filters/ /opt/cgit/filters/
COPY config/sshd_config /etc/ssh/sshd_config
COPY config/nginx/default.conf /etc/nginx/http.d/default.conf

# Copy git shell wrapper script and helper scripts
COPY scripts/ /opt/cgit/bin/
RUN chmod +x /opt/cgit/bin/*

# Add helper scripts to PATH
ENV PATH="/opt/cgit/bin:${PATH}"

# Environment variables for clone URLs and default owner
ENV CGIT_HOST="localhost"
ENV CGIT_OWNER="Unknown"

# Add architecture metadata
ARG TARGETPLATFORM
ARG BUILDPLATFORM
LABEL org.opencontainers.image.title="cgit Docker Image"
LABEL org.opencontainers.image.description="Fast web frontend for git repositories with SSH support"
LABEL target-platform="$TARGETPLATFORM"
LABEL build-platform="$BUILDPLATFORM"

# Copy s6-rc service definitions
COPY s6-rc/ /etc/s6-overlay/s6-rc.d/

# Set s6-overlay environment
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_LOGGING=0
ENV S6_VERBOSITY=2

# Expose ports
EXPOSE 80 22

# Declare volumes
VOLUME ["/opt/cgit/data"]

# Set entrypoint to s6-overlay init
ENTRYPOINT ["/init"]
