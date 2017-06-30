#!/usr/bin/env bash
docker stop wordpress-microserver &> /dev/null
docker rm wordpress-microserver &> /dev/null
