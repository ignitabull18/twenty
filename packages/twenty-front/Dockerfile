# Build stage
FROM node:18-alpine AS deps

# Install required packages for the build process
RUN apk add --no-cache bash git

WORKDIR /app

# Copy package files for better layer caching
COPY ../../package.json ../../yarn.lock ../../.yarnrc.yml ./
COPY ../../.yarn ./.yarn

# Copy workspace package files first for optimal caching
COPY ../../packages/twenty-front/package.json ./packages/twenty-front/package.json
COPY ../../packages/twenty-ui/package.json ./packages/twenty-ui/package.json
COPY ../../packages/twenty-shared/package.json ./packages/twenty-shared/package.json

# TEMPORARY: Allow lockfile update to incorporate new dependencies
# TODO: Change back to --immutable after lockfile is regenerated
RUN yarn install

FROM node:18-alpine AS builder
WORKDIR /app

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/twenty-ui/node_modules ./packages/twenty-ui/node_modules
COPY --from=deps /app/packages/twenty-shared/node_modules ./packages/twenty-shared/node_modules

# Copy source code
COPY ../../packages ./packages
COPY ../../tools ./tools
COPY ../../package.json ../../yarn.lock ../../.yarnrc.yml ./
COPY ../../.yarn ./.yarn

# Build the frontend application
WORKDIR /app/packages/twenty-front
RUN yarn build

# Production stage - Switch to Debian-based image to fix BusyBox user creation issue
FROM node:18-slim AS runner

# Install serve for production and wget for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install serve globally
RUN npm install -g serve

# Create app user for security using Debian-compatible commands
RUN addgroup --system app && adduser --system --group app

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=app:app /app/packages/twenty-front/build ./build

# Switch to non-root user
USER app

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

# Start the application
CMD ["serve", "-s", "build", "-l", "3000"]
