# One image for Fly.io: nginx (static app + /api proxy) and the Node API in the same machine.
# Upstream ships them as two containers (web/Dockerfile, api/Dockerfile). Fly's private network is
# IPv6-only and the upstream nginx template resolves with ipv6=off, so instead of two apps talking
# over .internal, both processes share one machine and nginx proxies to 127.0.0.1.
# Upstream files are used as-is (no edits), so `git merge upstream/main` stays conflict-free.

# ---- build the frontend (same steps as web/Dockerfile) ----
FROM --platform=$BUILDPLATFORM node:22-alpine AS build
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --ignore-scripts
COPY api/coach/core/ /app/api/coach/core/
COPY frontend/ ./
ARG APP_BUILD=""
RUN APP_BUILD="$APP_BUILD" npm run build

# ---- runtime ----
FROM node:22-alpine
RUN apk upgrade --no-cache \
 && apk add --no-cache nginx gettext su-exec tini \
 && rm -f /etc/nginx/http.d/default.conf

WORKDIR /app
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev --omit=optional && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
# Same module list as api/Dockerfile.
COPY api/server.js api/push-messages.js api/nudge.js api/nudge-copy.js api/verify-error.js api/password.js api/rate-limit.js api/passkeys-store.js api/device-link.js api/media.js api/queue.js api/sync-stamps.js api/durable.js ./
COPY api/coach ./coach

COPY web/nginx.conf.template /etc/nginx/opengym.conf.template
COPY --from=build /app/frontend/dist /usr/share/nginx/html
COPY catalogue/media/ /usr/share/nginx/html/exercise-media/
COPY --chmod=755 deploy/fly/start.sh /start.sh

ENV NODE_ENV=production \
    PORT=3000 \
    DATA_DIR=/data \
    NGINX_PORT=8080 \
    BACKEND=127.0.0.1 \
    RESOLVER=127.0.0.1 \
    BASE_PATH="" \
    MEDIA_UPLOAD_MAX=48m \
    CF_CONNECTING_IP='$http_fly_client_ip'

EXPOSE 8080
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/start.sh"]
