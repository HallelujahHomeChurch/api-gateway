#!/bin/sh
set -e

export OPENRESTY_HOME=${OPENRESTY_HOME:-/usr/local/openresty}
DOCKERIZE_BIN=/usr/local/bin/dockerize

for TEMPLATE in $(find ${OPENRESTY_HOME} -type f -name '*.tmpl' | sort -bfs); do
  DOCKERIZE_TEMPLATE_ARG="${DOCKERIZE_TEMPLATE_ARG} -template ${TEMPLATE}:${TEMPLATE/.tmpl/}"
done

# Run dockerize if there are templates to process
if [ -n "${DOCKERIZE_TEMPLATE_ARG}" ]; then
    ${DOCKERIZE_BIN} ${DOCKERIZE_TEMPLATE_ARG}
fi

echo "Starting api gateway..."

exec ${OPENRESTY_HOME}/bin/openresty -g "daemon off;"
