# syntax=docker/dockerfile:1
ARG ALPINE_VERSION=3.22
ARG S6_OVERLAY_VERSION=3.2.1.0

################################################################################
# Stage 1: Build cgit from source
################################################################################
FROM alpine:${ALPINE_VERSION} AS builder
ARG CGIT_GIT_URL=https://git.zx2c4.com/cgit
ARG CGIT_VERSION=master

RUN apk add --no-cache \
    git make gcc musl-dev openssl-dev zlib-dev \
    luajit-dev gettext-dev gettext && \
    git clone --depth 1 --single-branch ${CGIT_GIT_URL} . && \
    git checkout ${CGIT_VERSION} && \
    git submodule update --depth 1 --init --recursive

COPY cgit_build.conf /opt/cgit-build/cgit.conf

ENV NO_REGEX=NeedsStartEnd NO_GETTEXT=1

WORKDIR /opt/cgit-build
RUN make -j$(nproc) && make install

################################################################################
# Stage 2: Runtime image
################################################################################
FROM alpine:${ALPINE_VERSION}
ARG S6_OVERLAY_VERSION
ARG CHROMA_VERSION=2.14.0

RUN apk add --no-cache \
    git git-daemon nginx fcgiwrap spawn-fcgi \
    openssh-server bash shadow python3 \
    py3-markdown py3-pygments curl && \
    ln -sf python3 /usr/bin/python

RUN ARCH=$(case "$TARGETPLATFORM" in \
        "linux/amd64") echo "amd64" ;; \
        "linux/arm64") echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    curl -fsSL "https://github.com/alecthomas/chroma/releases/download/v${CHROMA_VERSION}/chroma-${CHROMA_VERSION}-linux-${ARCH}.tar.gz" -o /tmp/chroma.tar.gz && \
    tar -xz -C /usr/local/bin /tmp/chroma.tar.gz && \
    chmod +x /usr/local/bin/chroma && \
    rm /tmp/chroma.tar.gz

RUN ARCH=$(case "$TARGETPLATFORM" in \
        "linux/amd64") echo "x86_64" ;; \
        "linux/arm64") echo "aarch64" ;; \
        *) echo "x86_64" ;; \
    esac) && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" -o /tmp/noarch.tar.xz && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz" -o /tmp/arch.tar.xz && \
    tar -C / -Jxpf /tmp/noarch.tar.xz && \
    tar -C / -Jxpf /tmp/arch.tar.xz && \
    rm /tmp/*.tar.xz

COPY --from=builder /opt/cgit /opt/cgit
COPY entrypoint.sh /entrypoint.sh
COPY config/cgitrc /opt/cgit/cgitrc
COPY config/cgit-dark.css /opt/cgit/app/cgit-dark.css
COPY config/filters/ /opt/cgit/filters/
COPY config/sshd_config /etc/ssh/sshd_config
COPY config/nginx/default.conf /etc/nginx/http.d/default.conf
COPY scripts/ /opt/cgit/bin/

RUN chmod +x /entrypoint.sh /opt/cgit/bin/*

RUN addgroup -g 1000 git && \
    adduser -D -h /opt/cgit/data/repositories -u 1000 -G git -s /bin/sh git && \
    echo 'git:temp123' | chpasswd && \
    addgroup nginx git && \
    mkdir -p /opt/cgit/data/{repositories,cache,ssh,bin} /run/nginx /var/log/nginx && \
    touch /opt/cgit/data/ssh/authorized_keys && \
    chmod 700 /opt/cgit/data/ssh && \
    chmod 600 /opt/cgit/data/ssh/authorized_keys && \
    chown -R git:git /opt/cgit/data/ssh /opt/cgit/data/repositories && \
    chown -R nginx:nginx /opt/cgit/data/cache && \
    chmod 755 /opt/cgit/data/{repositories,cache,ssh} && \
    rm -f /etc/nginx/http.d/default.conf

ENV PATH="/opt/cgit/bin:${PATH}" \
    CGIT_HOST="localhost" \
    CGIT_OWNER="Unknown"

ARG TARGETPLATFORM ARG BUILDPLATFORM
LABEL org.opencontainers.image.title="cgit Docker Image" \
      org.opencontainers.image.description="Fast web frontend for git repositories with SSH support" \
      target-platform="$TARGETPLATFORM" \
      build-platform="$BUILDPLATFORM"

COPY s6-rc/ /etc/s6-overlay/s6-rc.d/

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_LOGGING=0 \
    S6_VERBOSITY=2

EXPOSE 80 22
VOLUME ["/opt/cgit/data"]
ENTRYPOINT ["/init"]
