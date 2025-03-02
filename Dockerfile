# Use a compatible Node.js version (20.17.0+)
FROM node:20.18.3-alpine AS server-dependencies

# Install required system dependencies
RUN apk -U upgrade && apk add --no-cache \
  python3 \
  py3-pip \
  py3-setuptools \
  build-base \
  bash \
  && ln -sf /usr/bin/python3 /usr/bin/python

WORKDIR /app

COPY server/package.json server/package-lock.json ./

# Install latest npm and pnpm (compatible with Node.js 20.17+)
RUN npm install -g npm@11.1.0 \
  && npm install -g pnpm@9 \
  && pnpm import \
  && pnpm install --prod

# Build the client
FROM node:20.18.3-alpine AS client

WORKDIR /app

COPY client .

RUN apk add --no-cache python3 py3-setuptools build-base \
  && npm install -g npm@11.1.0 \
  && npm install -g pnpm@9 \
  && pnpm import \
  && pnpm install --prod

RUN DISABLE_ESLINT_PLUGIN=true npm run build

# Final application image
FROM node:20.18.3-alpine

RUN apk -U upgrade && apk add --no-cache bash

WORKDIR /app

USER root
# Ensure node user has write access to /app directory by changing ownership
RUN chown -R node:node /app

# Set the working directory for the node user
USER node

COPY --chown=node:node start.sh .
COPY --chown=node:node healthcheck.js .
COPY --chown=node:node server .

RUN mv .env.sample .env

COPY --from=server-dependencies --chown=node:node /app/node_modules node_modules
COPY --from=client --chown=node:node /app/build public
COPY --from=client --chown=node:node /app/build/index.html views/index.ejs

VOLUME /app/public/user-avatars
VOLUME /app/public/project-background-images
VOLUME /app/private/attachments

EXPOSE 1337

HEALTHCHECK --interval=10s --timeout=2s --start-period=15s \
  CMD node ./healthcheck.js

CMD ["./start.sh"]
