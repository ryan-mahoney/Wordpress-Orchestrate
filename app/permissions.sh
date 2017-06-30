#!/usr/bin/env bash

# determine this files directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

chown www-data -R $DIR/../../app/*
chgrp www-data -R $DIR/../../app/*
chmod -R ug+rw $DIR/../../app/*
find $DIR/../../app -type d -exec chmod 777 {} +

if [ -n "$SUDO_USER" ]
    usermod -a -G $SUDO_USER www-data
    usermod -a -G www-data $SUDO_USER
    then
        chown $SUDO_USER -R $DIR/../../app/.git/*
        chgrp $SUDO_USER -R $DIR/../../app/.git/*
fi
