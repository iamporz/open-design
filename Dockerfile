# # ใช้ Node.js เวอร์ชัน 24 ตาม Requirement ของโปรเจกต์
# FROM node:24-slim

# # ติดตั้ง Python และ Build Tools สำหรับ compile better-sqlite3
# RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# # เปิดใช้งาน Corepack สำหรับ pnpm 10.33.2
# RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

# # กำหนด Working Directory
# WORKDIR /app

# # คัดลอก Source code ทั้งหมด
# COPY . .

# # ทริค: สร้างโฟลเดอร์และไฟล์ cli.js แบบว่างเปล่าหลอกๆ ไว้ล่วงหน้า 
# # เพื่อให้ pnpm install ทำ Symlink ผ่านโดยไม่มี Warning (เดี๋ยวตอน pnpm build มันจะเขียนไฟล์จริงทับลงไปเอง)
# RUN mkdir -p apps/daemon/dist && touch apps/daemon/dist/cli.js

# # ติดตั้ง Dependencies
# RUN pnpm install

# # Build โปรเจกต์
# RUN pnpm build

# # สร้างโฟลเดอร์ .od เตรียมไว้สำหรับ Mount ข้อมูล
# RUN mkdir -p /app/.od

# # Expose Port 3000 (สำหรับ Web)
# EXPOSE 3000

# # บังคับให้ Node.js และ Next.js เปิดรับการเชื่อมต่อจากภายนอก Container
# ENV HOST=0.0.0.0
# ENV HOSTNAME=0.0.0.0

# # ใช้คำสั่ง tools-dev เพื่อรัน Web และ Daemon ตามที่โปรเจกต์ระบุ
# # ระบุ --web-port ให้ชัดเจนเพื่อนำไปใช้ตั้งค่า Proxy ต่อ
# CMD ["pnpm", "tools-dev", "run", "web", "--web-port", "3000"]


FROM node:24-slim

# Install native build deps + socat for port forwarding
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    curl \
    socat \
  && rm -rf /var/lib/apt/lists/*

# Mock xdg-open so container won't crash when app tries to open browser
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open \
  && chmod +x /usr/local/bin/xdg-open

# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

WORKDIR /app

COPY . .

RUN pnpm install --frozen-lockfile

# Build web static export
RUN pnpm build

# Build daemon CLI
RUN pnpm --filter @open-design/daemon build

# Persistent data directory
RUN mkdir -p /app/.od

ENV NODE_ENV=production
ENV OD_DATA_DIR=/app/.od
ENV OD_CODEX_DISABLE_PLUGINS=1

# Traefik/Dokploy should point to this port
EXPOSE 8080

# Open Design daemon currently listens on 127.0.0.1:7456
# So we expose 0.0.0.0:8080 and forward it to daemon internal port
CMD ["/bin/sh", "-c", "node apps/daemon/dist/cli.js & socat TCP-LISTEN:8080,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:7456"]
