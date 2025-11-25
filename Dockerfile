# Build Backend with Frontend static files
FROM node:18-alpine

WORKDIR /app

# Copy backend package files first
COPY backend/package*.json ./backend/

# Install dependencies in backend directory
WORKDIR /app/backend
RUN npm install --production

# Go back to app root
WORKDIR /app

# Copy backend source code
COPY backend/ ./backend/

# Copy .env file
COPY backend/.env ./backend/

# Copy public folder
COPY backend/public ./backend/public/

# Copy Flutter Web build files
COPY frontend/build/web/ ./backend/public/web/

# Set working directory to backend for running
WORKDIR /app/backend

EXPOSE 3000

CMD ["node", "server.js"]
