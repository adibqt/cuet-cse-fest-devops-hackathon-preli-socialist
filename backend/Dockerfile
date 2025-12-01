
# Stage 1: Builder
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Runner
FROM node:20-alpine
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

# Create a non-root user for security
USER node

# Copy only necessary files from builder
COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/dist ./dist

# Install only production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

EXPOSE 3847

CMD ["node", "dist/index.js"]