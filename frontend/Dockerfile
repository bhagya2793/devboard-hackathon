# Stage 1 - Build React/Vite application
# ---------------------------------------------------------
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

RUN npm run build


# ---------------------------------------------------------
# Stage 2 - Production runtime
# No Node/npm/node_modules in the final image
# ---------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.30.4-alpine3.24

# Refresh Alpine packages, including OpenSSL security fixes.
# Root is used only during IMAGE BUILD.
USER root

RUN apk upgrade --no-cache

# NGINX unprivileged runtime user
USER 101

COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build --chown=101:101 \
    /app/dist \
    /usr/share/nginx/html

EXPOSE 8080

