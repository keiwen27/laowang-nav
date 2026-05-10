FROM node:18.19.1-alpine AS build_image

# Set the platform to build image for
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

# Config Alpine Mirror
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# Install additional tools needed if on arm64 / armv7
RUN \
  case "${TARGETPLATFORM}" in \
  'linux/arm64') apk add --no-cache python3 make g++ ;; \
  'linux/arm/v7') apk add --no-cache python3 make g++ ;; \
  esac

# Create and set the working directory
WORKDIR /app

# Install app dependencies
COPY package.json package-lock.json ./
RUN npm config set registry https://registry.npmmirror.com \
  && npm config set fetch-retries 3 \
  && npm config set fetch-retry-mintimeout 10000 \
  && npm config set fetch-retry-maxtimeout 120000 \
  && npm ci --ignore-scripts --no-audit --no-fund

# Copy over all project files and folders to the working directory
COPY . ./

# Backup default config for auto-initialization
RUN cp -r user-data user-data-example 2>/dev/null || true

# Build initial app for production
RUN npm run build -- --mode production

# Production stage
FROM node:20.11.1-alpine3.19

# Define some ENV Vars
ENV PORT=8080 \
  DIRECTORY=/app \
  IS_DOCKER=true

# Create and set the working directory
WORKDIR ${DIRECTORY}

# Update tzdata for setting timezone
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk add --no-cache tzdata

# Copy built application from build phase
COPY --from=build_image /app ./

# Finally, run start command to serve up the built application
CMD [ "npm", "start" ]

# Expose the port
EXPOSE ${PORT}

# Run simple healthchecks every 5 mins, to check that everythings still great
# Extended start-period to 120s to allow proper initialization (update checks, config validation, etc.)
HEALTHCHECK --interval=5m --timeout=10s --start-period=120s CMD npm run health-check
