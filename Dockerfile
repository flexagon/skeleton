# One container serves one site: every request, whatever its host name, goes
# to /app/$FLEXAGON_PUBLIC (default: public). Which domain points at which
# container is the load balancer's business, not the container's.
#
#   target dev          compose.yaml mounts the project at /app; Xdebug and
#                       composer. application/_Config.php is used as it is.
#   target alpha        the project is copied in, dependencies without
#   target beta         require-dev, production php.ini, runs as www-data.
#   target production   Each copies application/_Config/<stage>/ over
#                       application/, as the Ant build does for a server.
#                       production is last, so it is also the default.
#
#   docker build --target production -t myapp .
#   docker run -p 8080:8080 -e FLEXAGON_PUBLIC=public_admin -e DB_HOST=... myapp

ARG PHP_VERSION=8.3

# Add any other extension the application needs to PHP_EXTENSIONS.
#
# PHP extensions built into the base image (php:8.3-apache):
#   ctype curl date dom fileinfo filter hash iconv json libxml mbstring mysqlnd
#   openssl pcre PDO pdo_sqlite Phar posix random readline session SimpleXML
#   sodium sqlite3 tokenizer xml xmlreader xmlwriter zlib opcache
#
ARG PHP_EXTENSIONS="pdo_mysql pdo_pgsql opcache bcmath exif gd gettext intl zip"

# ---------------------------------------------------------------------- base --
FROM php:${PHP_VERSION}-apache AS base
ARG PHP_EXTENSIONS

# install-php-extensions installs the system libraries an extension needs and
# removes its build-only packages afterwards.
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions $PHP_EXTENSIONS

# Port 8080 so that Apache needs no root to bind it. Cloud Run and the like
# hand in their own PORT, which Apache reads when it starts.
ENV PORT=8080 \
    FLEXAGON_PUBLIC=public

# How many PHP processes Apache may run at once. auto divides the container's
# memory limit, less the reserve, by the per-process estimate. Raise the
# estimate for an application whose requests use more memory; a request may
# use up to memory_limit (128M), and the pool assumes they do not all at once.
# A process is replaced after this many connections, so a slow leak never
# outgrows the estimate.
ENV APACHE_MAX_REQUEST_WORKERS=auto \
    APACHE_WORKER_MEMORY_MB=48 \
    APACHE_RESERVED_MEMORY_MB=64 \
    APACHE_MAX_CONNECTIONS_PER_CHILD=1000

COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf
RUN set -eux; \
    echo 'Listen ${PORT}' > /etc/apache2/ports.conf; \
    echo 'ServerName localhost' > /etc/apache2/conf-available/servername.conf; \
    a2enconf servername; \
    a2enmod rewrite

COPY docker/entrypoint.sh /usr/local/bin/flexagon-entrypoint
RUN chmod 755 /usr/local/bin/flexagon-entrypoint

WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["flexagon-entrypoint"]
CMD ["apache2-foreground"]

# ----------------------------------------------------------------------- dev --
FROM base AS dev

# Xdebug is installed but not loaded. Only a container that adds this
# directory to PHP_INI_SCAN_DIR loads it -- web-xdebug in compose.yaml.
RUN set -eux; \
    pecl install xdebug; \
    rm -rf /tmp/pear; \
    cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; \
    echo 'opcache.revalidate_freq = 0' > "$PHP_INI_DIR/conf.d/zz-flexagon-dev.ini"
COPY docker/xdebug.ini /usr/local/etc/php/xdebug.d/xdebug.ini

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# --------------------------------------------------------------------- build --
FROM base AS build

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip; \
    rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# The whole project goes in before composer install, so that a path
# repository inside it (packages/...) is there to install from. The host's
# vendor/ stays out (.dockerignore): dependencies come from composer.lock,
# without require-dev, checked against this image's PHP and extensions.
# Downloads are kept in a build cache, not in the image, so a code change
# reinstalls without downloading again. A project on the phar has no
# composer.json and skips this.
COPY . .
RUN --mount=type=cache,target=/tmp/composer-cache \
    if [ -f composer.json ]; then \
        export COMPOSER_CACHE_DIR=/tmp/composer-cache; \
        composer install --no-dev --no-scripts --no-autoloader --no-interaction --prefer-dist; \
        composer dump-autoload --no-dev --optimize --no-interaction; \
    fi

# ------------------------------------------------------------- stage configs --
# Every file in application/_Config/<stage>/ replaces its namesake in
# application/, so _Config.php there becomes the application's _Config.php.
# A stage directory that does not exist fails the build.
FROM build AS config-alpha
RUN cp -a application/_Config/alpha/. application/

FROM build AS config-beta
RUN cp -a application/_Config/beta/. application/

FROM build AS config-production
RUN cp -a application/_Config/production/. application/

# ------------------------------------------------------------------- runtime --
FROM base AS runtime

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php-production.ini "$PHP_INI_DIR/conf.d/zz-flexagon-production.ini"

# --------------------------------------------------------------------- stages --
# Code is owned by root and only readable by www-data: a request cannot
# rewrite it. flexagon check fails the build on a layout or config problem;
# settings that only the runtime environment supplies show up as warnings and
# do not stop it. Another stage is one more config-<stage> and one more block.
FROM runtime AS alpha
COPY --from=config-alpha /app /app
RUN if [ -f vendor/bin/flexagon ]; then php vendor/bin/flexagon check; fi
USER www-data

FROM runtime AS beta
COPY --from=config-beta /app /app
RUN if [ -f vendor/bin/flexagon ]; then php vendor/bin/flexagon check; fi
USER www-data

FROM runtime AS production
COPY --from=config-production /app /app
RUN if [ -f vendor/bin/flexagon ]; then php vendor/bin/flexagon check; fi
USER www-data
