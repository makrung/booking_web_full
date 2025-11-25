# Build Backend with Frontend static files
# Force rebuild: v2
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
RUN rm -rf ./backend/public/web && mkdir -p ./backend/public/web

# Copy Flutter Web build files (all contents including subdirectories)
COPY --chown=node:node frontend/build/web ./backend/public/web

# Verify files copied - should see index.html, main.dart.js and other files
RUN echo "=== Verifying web files ===" && \
    ls -lah ./backend/public/web/ && \
    echo "=== Checking index.html ===" && \
    test -f ./backend/public/web/index.html || (echo "ERROR: index.html not found!" && exit 1) && \
    echo "=== Checking main.dart.js ===" && \
    test -f ./backend/public/web/main.dart.js || (echo "ERROR: main.dart.js not found!" && exit 1) && \
    echo "=== All files verified successfully ==="

# Set working directory to backend for running
WORKDIR /app/backend

EXPOSE 3000

CMD ["node", "server.js"]
