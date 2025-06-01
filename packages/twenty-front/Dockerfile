# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY ../../package.json ../../pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# Copy only the front-end package
COPY ../../packages/twenty-front ./packages/twenty-front
WORKDIR /app/packages/twenty-front
RUN pnpm build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/packages/twenty-front ./
RUN npm install -g pnpm
ENV PORT=3000
CMD ["pnpm", "start"]
