#!/usr/bin/env bash

# determine this files directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ENV="local"
if [ $# -eq 1 ]
then
    ENV=$1
fi

PERSISTENT_DIR="$DIR/../../persistent"
docker pull opinephp/wordpress-microserver
    mkdir -p /app/persistent
    PERSISTENT_DIR="/app/persistent"
else
    mkdir -p "$PERSISTENT_DIR"/log
fi

docker stop wordpress-microserver &> /dev/null
docker rm wordpress-microserver &> /dev/null

docker run \
    --name wordpress-microserver \
    -p 80:80 \
    -v "$DIR/../../app":/app \
    -v "$DIR/../../db":/db \
    -v "$DIR/../../wp-content":/app/wordpress/wp-content \
    -v "$PERSISTENT_DIR":/media/persistent \
    --cap-add SYS_RESOURCE --cap-add SYS_TIME \
    -d opinephp/wordpress-microserver

echo "TO ENTER CONTAINER, RUN: sudo docker exec -i -t wordpress-microserver /bin/bash"
