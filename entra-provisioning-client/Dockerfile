FROM node:20-alpine AS builder

WORKDIR /app

# Install server dependencies
COPY package*.json ./
RUN npm ci --production=false

# Install client dependencies and build
COPY client/package*.json ./client/
RUN cd client && npm ci
COPY client/ ./client/
RUN cd client && npm run build

# Production image
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY server/ ./server/
COPY --from=builder /app/client/build ./client/build

EXPOSE 3001

ENV NODE_ENV=production
CMD ["node", "server/index.js"]
