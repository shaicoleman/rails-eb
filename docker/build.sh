#!/bin/bash
cd "$(dirname "$0")"
source config/env.sh
DOCKER_BUILDKIT=1 \
  docker build --progress=plain --rm --build-arg RAILS_ENV="$RAILS_ENV" --build-arg NODE_ENV="$NODE_ENV" --file Dockerfile -t al2 .. || exit 1
