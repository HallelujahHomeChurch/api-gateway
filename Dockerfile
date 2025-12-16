# --- Stage 1: The Builder ---
FROM openresty/openresty:alpine-fat AS builder

RUN apk add --no-cache curl git make gcc musl-dev

WORKDIR /tmp
RUN opm get ledgetech/lua-resty-http
RUN opm get SkyLothar/lua-resty-jwt

# --- Stage 2: The Final Image ---
FROM openresty/openresty:alpine

RUN set -x \
    && addgroup -S -g 101 nginx \
    && adduser -S -G nginx -u 101 -s /sbin/nologin nginx

# Copy OPM modules
COPY --from=builder /usr/local/openresty/site/lualib /usr/local/openresty/site/lualib
COPY --from=builder /usr/local/openresty/lualib /usr/local/openresty/lualib

# Copy nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY conf.d/ /usr/local/openresty/nginx/conf/conf.d/

# Copy custom Lua modules
COPY lua/ /usr/local/openresty/lualib/

# Copy static files (favicon, etc.)
COPY www/ /usr/local/openresty/nginx/html/

# Expose port
EXPOSE 10000
