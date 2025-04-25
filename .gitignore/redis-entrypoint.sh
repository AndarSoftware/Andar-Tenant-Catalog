#!/bin/sh

# Read Redis password from the Docker secret
REDIS_PASSWORD=$(cat /run/secrets/redis_password)

# Start Redis server with the password
exec redis-server --requirepass "$REDIS_PASSWORD" --save 60 1 --loglevel warning
