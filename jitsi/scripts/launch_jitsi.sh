#!/usr/bin/env bash
set -ex

export DOCKER_HOST_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
docker-compose up --force-recreate