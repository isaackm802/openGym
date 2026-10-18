#!/bin/sh
# Starts the API (as the unprivileged `node` user) and nginx; if either exits, the machine exits
# and Fly restarts it.
set -eu

mkdir -p "$DATA_DIR" /run/nginx
chown node:node "$DATA_DIR"

# Render the upstream nginx template with only its own variables, so nginx's $vars survive.
envsubst '${NGINX_PORT} ${BACKEND} ${PORT} ${RESOLVER} ${CF_CONNECTING_IP} ${BASE_PATH} ${MEDIA_UPLOAD_MAX}' \
  < /etc/nginx/opengym.conf.template > /etc/nginx/http.d/opengym.conf

# HSTS: Fly terminates TLS, and the upstream template leaves HSTS to the proxy. Every location
# that sets headers repeats X-Frame-Options, so adding it next to that line covers them all.
sed -i 's|add_header X-Frame-Options "DENY" always;|add_header X-Frame-Options "DENY" always;\n    add_header Strict-Transport-Security "max-age=31536000" always;|' /etc/nginx/http.d/opengym.conf

nginx -t

su-exec node node /app/server.js &
API_PID=$!
nginx -g 'daemon off;' &
NGINX_PID=$!

trap 'kill -TERM $API_PID $NGINX_PID 2>/dev/null' TERM INT
# Exit as soon as either process dies.
while kill -0 $API_PID 2>/dev/null && kill -0 $NGINX_PID 2>/dev/null; do sleep 2; done
kill -TERM $API_PID $NGINX_PID 2>/dev/null || true
wait || true
exit 1
