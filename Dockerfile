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

# Try to copy Flutter Web build files if they exist, otherwise create empty directory
RUN mkdir -p ./backend/public/web

# For now, we'll skip copying web files since they may not be in the repo
# If needed later, they can be added via a separate build step or mounted volume

WORKDIR /app/backend

EXPOSE 3000

CMD ["node", "server.js"]
