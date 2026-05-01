# ใช้ Node.js เวอร์ชัน 24 ตาม Requirement ของโปรเจกต์
FROM node:24-slim

# ติดตั้ง Python และ Build Tools สำหรับ compile better-sqlite3
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# เปิดใช้งาน Corepack สำหรับ pnpm 10.33.2
RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

# กำหนด Working Directory
WORKDIR /app

# คัดลอก Source code ทั้งหมด
COPY . .

# ติดตั้ง Dependencies
RUN pnpm install

# Build โปรเจกต์
RUN pnpm build

# สร้างโฟลเดอร์ .od เตรียมไว้สำหรับ Mount ข้อมูล
RUN mkdir -p /app/.od

# Expose Port 3000 (สำหรับ Web)
EXPOSE 3000

# ใช้คำสั่ง tools-dev เพื่อรัน Web และ Daemon ตามที่โปรเจกต์ระบุ
# ระบุ --web-port ให้ชัดเจนเพื่อนำไปใช้ตั้งค่า Proxy ต่อ
CMD ["pnpm", "tools-dev", "run", "web", "--web-port", "3000"]
