# --- Stage 1: The Builder ---
FROM openresty/openresty:alpine-fat AS builder

RUN apk add --no-cache curl git make gcc musl-dev

ENV DOCKERIZE_VERSION=v0.9.7

RUN arch=$(uname -m) \
 && case ${arch} in \
      x86_64) dockerize_arch=amd64 ;; \
      aarch64) dockerize_arch=arm64 ;; \
      *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac \
 && apk update \
 && apk add --no-cache wget openssl \
 && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-${dockerize_arch}-$DOCKERIZE_VERSION.tar.gz \
 && tar -C /usr/local/bin -xzvf dockerize-linux-${dockerize_arch}-$DOCKERIZE_VERSION.tar.gz

WORKDIR /tmp
RUN opm get ledgetech/lua-resty-http

# --- Stage 2: The Final Image ---
FROM openresty/openresty:alpine

ENV OPENRESTY_HOME=/usr/local/openresty
ENV EXPOSE_PORT=10000
ENV SERVER_NAME=localhost

RUN set -x \
    && addgroup -S -g 101 nginx \
    && adduser -S -G nginx -u 101 -s /sbin/nologin nginx

# Copy dockerize
COPY --from=builder /usr/local/bin/dockerize /usr/local/bin/dockerize

# Copy OPM modules
COPY --from=builder ${OPENRESTY_HOME}/site/lualib ${OPENRESTY_HOME}/site/lualib
COPY --from=builder ${OPENRESTY_HOME}/lualib ${OPENRESTY_HOME}/lualib

# Copy nginx configuration
COPY nginx.conf.tmpl ${OPENRESTY_HOME}/nginx/conf/nginx.conf.tmpl
COPY conf.d/ ${OPENRESTY_HOME}/nginx/conf/conf.d/

# Copy custom Lua modules
COPY lua/ ${OPENRESTY_HOME}/lualib/

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port
EXPOSE ${EXPOSE_PORT}

CMD ["/entrypoint.sh"]