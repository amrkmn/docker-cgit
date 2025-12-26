# syntax=docker/dockerfile:1
ARG ALPINE_VERSION=3.22
ARG S6_OVERLAY_VERSION=3.2.1.0

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

# Clone cgit and checkout version
RUN git clone --depth 1 ${CGIT_GIT_URL} . && \
    git checkout ${CGIT_VERSION} && \
    git submodule update --init --recursive

# Copy build configuration
COPY cgit_build.conf /opt/cgit-build/cgit.conf

# Build and install cgit
RUN make && make install

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
    # User management for PUID/PGID
    shadow \
    # Python for syntax highlighting
    python3 \
    py3-pip \
    py3-pygments \
    py3-markdown \
    # Lua support
    luajit \
    lua5.1-http \
    # Utilities
    mailcap \
    groff \
    xz

# Install rst2html via pip
RUN python3 -m pip install --no-cache-dir --break-system-packages docutils && \
    ln -sf python3 /usr/bin/python

# Download and install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

# Copy cgit from builder stage
COPY --from=builder /opt/cgit /opt/cgit

# Create git user and group (UID/GID 1000)
RUN addgroup -g 1000 git && \
    adduser -D -h /opt/cgit/repositories -u 1000 -G git -s /bin/sh git && \
    mkdir -p /opt/cgit/ssh && \
    touch /opt/cgit/ssh/authorized_keys && \
    chmod 700 /opt/cgit/ssh && \
    chmod 600 /opt/cgit/ssh/authorized_keys && \
    chown -R git:git /opt/cgit/ssh && \
    chown -R git:git /opt/cgit/repositories && \
    echo 'git:temp123' | chpasswd

# Add nginx to git group for read access to repositories
RUN addgroup nginx git

# Create directory structure
RUN mkdir -p /opt/cgit/repositories /opt/cgit/cache /opt/cgit/bin && \
    chown -R git:git /opt/cgit/repositories && \
    chown -R nginx:nginx /opt/cgit/cache && \
    chmod 755 /opt/cgit/repositories && \
    chmod 755 /opt/cgit/cache

# Create nginx directories
RUN mkdir -p /run/nginx /var/log/nginx && \
    chown -R nginx:nginx /run/nginx /var/log/nginx

# Remove default nginx config that conflicts before copying our config
RUN rm -f /etc/nginx/http.d/default.conf

# Copy configuration files
COPY config/cgitrc /opt/cgit/cgitrc
COPY config/sshd_config /etc/ssh/sshd_config
COPY config/nginx/default.conf /etc/nginx/http.d/default.conf

# Copy git shell wrapper script and helper scripts
COPY scripts/git-shell-wrapper.sh /opt/cgit/bin/git-shell-wrapper.sh
COPY scripts/init-bare-repo.sh /opt/cgit/bin/init-bare-repo.sh
COPY scripts/clone-repo.sh /opt/cgit/bin/clone-repo.sh
RUN chmod 755 /opt/cgit/bin/git-shell-wrapper.sh && \
    chmod 755 /opt/cgit/bin/init-bare-repo.sh && \
    chmod 755 /opt/cgit/bin/clone-repo.sh

# Copy s6-rc service definitions
COPY s6-rc/ /etc/s6-overlay/s6-rc.d/

# Set s6-overlay environment
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_LOGGING=0
ENV S6_VERBOSITY=2

# Expose ports
EXPOSE 80 22

# Declare volumes
VOLUME ["/opt/cgit/repositories", "/opt/cgit/ssh"]

# Set entrypoint to s6-overlay init
ENTRYPOINT ["/init"]
