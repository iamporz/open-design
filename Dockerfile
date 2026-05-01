FROM node:24-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    git \
    python3 \
    make \
    g++ \
    curl \
    socat \
    bash \
  && rm -rf /var/lib/apt/lists/*

# Prevent crash: Error spawn xdg-open ENOENT
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open \
  && chmod +x /usr/local/bin/xdg-open

RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

WORKDIR /app

# สำคัญ: ต้อง COPY ทั้ง repo ก่อน pnpm install
# เพราะ root package.json มี postinstall: node ./scripts/postinstall.mjs
COPY . .

# กันกรณี postinstall/bin link ต้องการ cli.js ก่อน build
RUN mkdir -p apps/daemon/dist \
  && touch apps/daemon/dist/cli.js

RUN pnpm install --frozen-lockfile

# Build web static export
RUN pnpm build

# Build daemon CLI
RUN pnpm --filter @open-design/daemon build

RUN mkdir -p /app/.od

ENV NODE_ENV=production
ENV OD_DATA_DIR=/app/.od
ENV OD_RESOURCE_ROOT=/app
ENV OD_CODEX_DISABLE_PLUGINS=1

EXPOSE 8080

CMD ["/bin/sh", "-c", "node apps/daemon/dist/cli.js & socat TCP-LISTEN:8080,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:7456"]
