#!/usr/bin/env bash

# determine this files directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker pull opinephp/wordpress-microserver

mkdir -p /app/persistent

docker run \
    --name wordpress-microserver \
    -p 80:80 \
    -v "$DIR":/app \
    -v /app/db:/db \
    -v /app/wp-content:/app/wordpress/wp-content \
    -v /app/persistent:/media/persistent \
    --cap-add SYS_RESOURCE --cap-add SYS_TIME \
    -d opinephp/wordpress-microserver
