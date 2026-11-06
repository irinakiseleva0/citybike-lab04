# ---------- Stage 1: build ----------
FROM node:20 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG GITHUB_SHA=local-dev
ENV GITHUB_SHA=$GITHUB_SHA
RUN npm run build

# ---------- Stage 2: run ----------
FROM node:20-alpine
WORKDIR /app
COPY --from=build --chown=node:node /app/server.js ./
COPY --from=build --chown=node:node /app/public ./public
COPY --from=build --chown=node:node /app/dist/build-manifest.json ./dist/build-manifest.json
USER node
EXPOSE 4173
CMD ["node", "server.js"]
