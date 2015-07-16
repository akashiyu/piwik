#!/bin/bash
if [ "$SKIP_PIWIK_TEST_PREPARE" == "1" ]; then
    echo "Skipping webserver setup."
    exit 0;
fi

set -e

DIR=$(readlink -f $(dirname "$0"))

service nginx stop

# Setup PHP-FPM
echo "Configuring php-fpm"

if [[ "$TRAVIS_PHP_VERSION" == 5.3* ]];
then
    # path does not exist with 5.3.3 so use 5.3 
    PHP_FPM_BIN="$HOME/.phpenv/versions/5.3/sbin/php-fpm"
else
    PHP_FPM_BIN="$HOME/.phpenv/versions/$TRAVIS_PHP_VERSION/sbin/php-fpm"
fi;

PHP_FPM_CONF="$DIR/php-fpm.conf"
PHP_FPM_SOCK=$(realpath "$DIR")/php-fpm.sock

if [ -d "$TRAVIS_BUILD_DIR/../piwik/tmp/" ]; then
    PHP_FPM_LOG="$TRAVIS_BUILD_DIR/../piwik/tmp/php-fpm.log"
elif [ -d "$TRAVIS_BUILD_DIR/piwik/tmp/" ]; then
    PHP_FPM_LOG="$TRAVIS_BUILD_DIR/piwik/tmp/php-fpm.log"
elif [ -d "$TRAVIS_BUILD_DIR" ]; then
    PHP_FPM_LOG="$TRAVIS_BUILD_DIR/php-fpm.log"
else
    PHP_FPM_LOG="$HOME/php-fpm.log"
fi

USER=$(whoami)

echo "php-fpm user = $USER"

touch "$PHP_FPM_LOG"

# Adjust php-fpm.ini
sed -i "s/@USER@/$USER/g" "$DIR/php-fpm.ini"
sed -i "s|@PHP_FPM_SOCK@|$PHP_FPM_SOCK|g" "$DIR/php-fpm.ini"
sed -i "s|@PHP_FPM_LOG@|$PHP_FPM_LOG|g" "$DIR/php-fpm.ini"
sed -i "s|@PATH@|$PATH|g" "$DIR/php-fpm.ini"

# Setup nginx
echo "Configuring nginx"
PIWIK_ROOT=$(realpath "$DIR/../..")
NGINX_CONF="/etc/nginx/nginx.conf"

sed -i "s|@PIWIK_ROOT@|$PIWIK_ROOT|g" "$DIR/piwik_nginx.conf"
sed -i "s|@PHP_FPM_SOCK@|$PHP_FPM_SOCK|g" "$DIR/piwik_nginx.conf"

cp $NGINX_CONF "$DIR/nginx.conf"
sed -i "s|/etc/nginx/sites-enabled/\\*|$DIR/piwik_nginx.conf|g" "$DIR/nginx.conf"
sed -i "s|user www-data|user $USER|g" "$DIR/nginx.conf"
sed -i "s|access_log .*;|access_log $DIR/access.log;|g" "$DIR/nginx.conf"
sed -i "s|error_log .*;|error_log $DIR/error.log;|g" "$DIR/nginx.conf" # TODO: replace reference in .travis.yml

cat "$DIR/nginx.conf"

# Start daemons
echo "Starting php-fpm"
$PHP_FPM_BIN --fpm-config "$DIR/php-fpm.ini"

echo "Starting nginx"
nginx -c "$DIR/nginx.conf"
