#!/bin/bash
echo "Run health-status.py server"
# bind port 8282, only root can bind 82
uvicorn health-status:app --reload  --port 8282

# gunicorn --bind 0.0.0.0:80 --workers 1 -k uvicorn.workers.UvicornWorker health-status:app
