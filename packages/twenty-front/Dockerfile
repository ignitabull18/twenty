# Build stage
FROM node:18-alpine AS builder

# Install required packages for the build process
RUN apk add --no-cache bash

WORKDIR /app

# Copy package files
COPY ../../package.json ../../yarn.lock ../../.yarnrc.yml ./
COPY ../../.yarn ./.yarn

# Copy workspace package files first for better layer caching
COPY ../../packages/twenty-front/package.json ./packages/twenty-front/package.json
COPY ../../packages/twenty-ui/package.json ./packages/twenty-ui/package.json
COPY ../../packages/twenty-shared/package.json ./packages/twenty-shared/package.json

# Install dependencies
RUN yarn install --immutable

# Copy the entire repository structure needed for build
COPY ../../packages ./packages
COPY ../../tools ./tools

# Build the frontend application
WORKDIR /app/packages/twenty-front
RUN yarn build

# Production stage
FROM node:18-alpine

# Install serve for production
RUN npm install -g serve

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/packages/twenty-front/build ./build

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Start the application
CMD ["serve", "-s", "build", "-l", "3000"]
