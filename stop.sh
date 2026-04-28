#!/bin/bash

stop_celery_worker() {
    echo "Stopping Celery worker..."
    pkill -f 'celery worker'
}

stop_fastapi() {
    echo "Stopping FastAPI..."
    pkill -f uvicorn
}

stop_redis() {
    echo "Stopping Redis..."
    if which redis-cli > /dev/null; then
        # Try to shutdown Redis gracefully
        redis-cli shutdown NOSAVE
    else
        echo "Redis CLI not available."
    fi

    # Wait a moment to allow for a graceful shutdown
    sleep 2

    # Check if Redis is still running and try to kill it
    if pgrep -f 'redis-server' > /dev/null; then
        echo "Redis server is still running, trying to kill..."
        pkill -9 -f 'redis-server'
    else
        echo "Redis server stopped successfully."
    fi
}


# Call the stop functions
stop_celery_worker
stop_fastapi
stop_redis

echo "Services stopped."
