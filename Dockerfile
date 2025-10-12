FROM nginx:1.28-alpine

# Module versions
ARG HEADERS_MORE_VERSION=0.39

LABEL maintainer="rayselfs@alive.org.tw" \
      description="Production-ready API Gateway with headers-more module" \
      version="1.1" \
      headers-more-version="${HEADERS_MORE_VERSION}"

# Install build dependencies and headers-more-nginx-module
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    && NGINX_VERSION=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p') \
    && cd /tmp \
    && curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz \
    && curl -fSL https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz -o headers-more.tar.gz \
    && tar -xzf nginx.tar.gz \
    && tar -xzf headers-more.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure --with-compat --add-dynamic-module=../headers-more-nginx-module-${HEADERS_MORE_VERSION} \
    && make modules \
    && cp objs/ngx_http_headers_more_filter_module.so /etc/nginx/modules/ \
    && cd / \
    && rm -rf /tmp/* \
    && apk del .build-deps

# Create nginx cache directories
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chmod -R 755 /var/cache/nginx

# Copy nginx main configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Remove all existing configurations
RUN rm -rf /etc/nginx/conf.d/*

# Copy all conf.d configurations
COPY conf.d/ /etc/nginx/conf.d/

# Validate nginx configuration
RUN nginx -t

EXPOSE 10000
