# Build Frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy Flutter pubspec.yaml (ถ้ามี)
# Note: ถ้า Flutter Web ยังไม่ได้ build ให้ skip
# COPY frontend/ .
# RUN flutter pub get && flutter build web

# Build Backend
FROM node:18-alpine

WORKDIR /app

# Copy backend
COPY backend/package*.json ./backend/
WORKDIR /app/backend

RUN npm install --production

# Copy backend source
COPY backend/ .

# Copy .env
COPY backend/.env .

# Copy public folder
COPY backend/public /app/backend/public

EXPOSE 3000

CMD ["npm", "start"]
