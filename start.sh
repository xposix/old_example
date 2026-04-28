#!/bin/bash

check_redis_installed() {
    which redis-server > /dev/null
    if [ $? -ne 0 ]; then
        echo "Redis is not installed. Installing Redis..."
        install_redis
    else
        echo "Redis is already installed."
    fi
}

install_redis() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        apt-get update && apt-get install -y redis-server
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        brew install redis
    else
        echo "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

start_redis() {
    echo "Starting Redis..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        redis-server /etc/redis/redis.conf &
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew services start redis
    fi
}

start_celery_worker() {
    echo "Starting Celery worker with debug logging..."
    celery -A service.celery_app.celery_app worker --pool=solo --concurrency=1 --loglevel=debug &
}

start_fastapi() {
    echo "Starting FastAPI with debug logging..."
    gunicorn service.app:app -w 1 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8081 --log-level debug
}

check_redis_installed
start_redis
start_celery_worker
start_fastapi

# Wait for all background processes to finish
wait
