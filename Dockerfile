FROM node:24-alpine

# Recognition uses a 16 kHz copy while preserving the child's original WAV.
RUN apk add --no-cache ffmpeg

WORKDIR /app
COPY backend ./backend
COPY admin ./admin

# The server binds to loopback by default, which a container port mapping cannot reach.
ENV HOST=0.0.0.0 \
    PORT=8787 \
    DATA_DIR=/data \
    NODE_ENV=production

# Created before VOLUME so a new named volume inherits node ownership.
RUN mkdir /data && chown node:node /data
VOLUME /data
EXPOSE 8787

USER node
WORKDIR /app/backend
CMD ["npm", "run", "demo"]
