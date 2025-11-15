#!/bin/sh
set -e

export OPENRESTY_HOME=${OPENRESTY_HOME:-/usr/local/openresty}

for TEMPLATE in $(find ${OPENRESTY_HOME} -type f -name '*.tmpl' | sort -bfs); do
  DOCKERIZE_TEMPLATE_ARG="${DOCKERIZE_TEMPLATE_ARG} -template ${TEMPLATE}:${TEMPLATE/.tmpl/}"
done

dockerize ${DOCKERIZE_TEMPLATE_ARG}

echo "Starting api gateway..."

exec ${OPENRESTY_HOME}/bin/openresty -g "daemon off;"
