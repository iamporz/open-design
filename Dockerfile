# ใช้ Node.js เวอร์ชัน 24 ตามที่โปรเจกต์กำหนด
FROM node:24-slim

# เปิดใช้งาน Corepack สำหรับ pnpm
RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

# กำหนด Working Directory
WORKDIR /app

# คัดลอกไฟล์ทั้งหมดลงใน Container
COPY . .

# ติดตั้ง Dependencies
RUN pnpm install

# Build โปรเจกต์สำหรับ Production (Frontend + Daemon)
RUN pnpm build
RUN pnpm --filter @open-design/daemon build

# Expose พอร์ตที่ Daemon ใช้งาน
EXPOSE 7456

# คำสั่งสำหรับรันโปรเจกต์ในโหมด Production
CMD ["npm", "start"]
