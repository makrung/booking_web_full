# Build Backend with Frontend static files
FROM node:18-alpine

WORKDIR /app

# Copy backend package files
COPY backend/package*.json ./backend/

# Install dependencies
RUN cd backend && npm install --production

# Copy backend source code
COPY backend/ ./backend/

# Copy .env file
COPY backend/.env ./backend/

# Copy public folder
COPY backend/public ./backend/public/

# Copy Flutter Web build files
COPY frontend/build/web/ ./backend/public/web/

WORKDIR /app/backend

EXPOSE 3000

CMD ["node", "server.js"]
