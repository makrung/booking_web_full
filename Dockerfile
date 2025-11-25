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

# Remove old web files if exist
RUN rm -rf ./backend/public/web

# Copy Flutter Web build files
COPY frontend/build/web/ ./backend/public/web/

# Verify files copied
RUN ls -la ./backend/public/web/ || echo "Web files not found"

# Set working directory to backend for running
WORKDIR /app/backend

EXPOSE 3000

CMD ["node", "server.js"]
