FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy code
COPY . .

# Build application
RUN npm run build

# Use lightweight server
RUN npm install -g serve

# Security constraints
RUN addgroup -S banking && adduser -S banking -G banking
USER banking

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:3000 || exit 1

CMD ["serve", "-s", "build", "-l", "tcp://0.0.0.0:3000"]
