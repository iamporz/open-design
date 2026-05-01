FROM node:24-slim

# Native deps:
# - python3/make/g++ สำหรับ native node modules
# - curl สำหรับ healthcheck/debug
# - socat สำหรับ expose 8080 -> daemon internal 7456
# - git/ca-certificates เผื่อ agent/tool ต้องอ่าน repo metadata หรือ HTTPS
# - xdg-utils ไม่จำเป็นจริง เพราะเราจะ mock xdg-open เอง
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

# ป้องกัน daemon พยายามเปิด browser ใน container แล้ว crash:
# Error: spawn xdg-open ENOENT
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open \
  && chmod +x /usr/local/bin/xdg-open

RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

WORKDIR /app

# Copy dependency manifests ก่อนเพื่อ cache install ให้ดีขึ้น
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Copy package manifests ของ workspace ที่จำเป็น
COPY apps/web/package.json ./apps/web/package.json
COPY apps/daemon/package.json ./apps/daemon/package.json
COPY packages ./packages
COPY tools ./tools

RUN pnpm install --frozen-lockfile

# Copy source + runtime resources ทั้งหมดที่ Open Design ใช้จริง
COPY apps ./apps
COPY assets ./assets
COPY design-systems ./design-systems
COPY docs ./docs
COPY prompt-templates ./prompt-templates
COPY scripts ./scripts
COPY skills ./skills
COPY specs ./specs
COPY story ./story
COPY templates ./templates
COPY AGENTS.md CLAUDE.md README.md QUICKSTART.md LICENSE ./

# Build frontend static export -> apps/web/out
RUN pnpm build

# Build daemon CLI -> apps/daemon/dist/cli.js
RUN pnpm --filter @open-design/daemon build

# Runtime data: ต้อง mount volume ที่ path นี้ใน Dokploy
RUN mkdir -p /app/.od

ENV NODE_ENV=production
ENV OD_DATA_DIR=.od
ENV OD_CODEX_DISABLE_PLUGINS=1

# Optional แต่ช่วยให้ daemon หา resource แบบ explicit
ENV OD_RESOURCE_ROOT=/app

EXPOSE 8080

# จาก log ของป้อ daemon listen ที่ 127.0.0.1:7456
# Traefik/Dokploy ยิงเข้า 8080 ดังนั้น forward 8080 -> 7456
CMD ["/bin/sh", "-c", "node apps/daemon/dist/cli.js & socat TCP-LISTEN:8080,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:7456"]
