FROM pietervandereems/armhf-alpine:3.5
#FROM alpine:3.5

LABEL maintainer "Pieter van der Eems<github@eemco.nl>"

COPY cross-build-end cross-build-start qemu-arm-static sh-shim /usr/bin/

RUN [ "cross-build-start" ]

# grab su-exec for easy step-down from root
RUN apk add --no-cache 'su-exec>=0.2'

# add "bash" for "[["
RUN apk add --no-cache \
		bash \
		nodejs \
		make \
		gcc \
        g++ \
        libc-dev \
		python2

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_ENV production
ENV GHOST_CLI_VERSION 1.1.1
ENV GHOST_VERSION 1.6.2
#ENV PYTHON python2

ENV GHOST_INSTALL /var/lib/ghost
ENV GHOST_CONTENT /var/lib/ghost/content

RUN adduser -D node

RUN mkdir -p /home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:$PATH
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
RUN chown -R node:node /home/node/.npm-global

RUN su-exec node npm install -g "ghost-cli@$GHOST_CLI_VERSION" knex-migrator@latest

RUN set -ex; \
	mkdir -p "$GHOST_INSTALL"; \
	chown node:node "$GHOST_INSTALL"; \
	\
	su-exec node ghost install "$GHOST_VERSION" --db sqlite3 --no-prompt --no-stack --no-setup --dir "$GHOST_INSTALL"; \
	\
# Tell Ghost to listen on all ips and not prompt for additional configuration
	cd "$GHOST_INSTALL"; \
	su-exec node ghost config --ip 0.0.0.0 --port 2368 --no-prompt --db sqlite3 --url http://localhost:2368 --dbpath "$GHOST_CONTENT/data/ghost.db"; \
	su-exec node ghost config paths.contentPath "$GHOST_CONTENT"; \
	\
# need to save initial content for pre-seeding empty volumes
	mv "$GHOST_CONTENT" "$GHOST_INSTALL/content.orig"; \
	mkdir -p "$GHOST_CONTENT"; \
	chown node:node "$GHOST_CONTENT"

WORKDIR $GHOST_INSTALL
VOLUME $GHOST_CONTENT

COPY docker-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-entrypoint.sh"]

RUN [ "cross-build-end" ]


EXPOSE 2368
CMD ["node", "current/index.js"]

