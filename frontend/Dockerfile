FROM node:20-alpine

WORKDIR /app

# Instaliraj dependencije
COPY package.json ./
RUN npm install

# Kopiraj kod
COPY . .

# Build aplikaciju
RUN npm run build

# Koristi lightweight server
RUN npm install -g serve

# Sigurnosna ograničenja
RUN addgroup -S banking && adduser -S banking -G banking
USER banking

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:3000 || exit 1

CMD ["serve", "-s", "build", "-l", "tcp://0.0.0.0:3000"]
