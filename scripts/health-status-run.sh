#!/bin/bash
echo "Run health-status.py server"
uvicorn health-status:app --reload

# gunicorn --bind 0.0.0.0:80 --workers 1 -k uvicorn.workers.UvicornWorker health-status:app
