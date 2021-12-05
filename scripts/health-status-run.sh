#!/bin/bash
echo "Run health-status.py server"
uvicorn health-status:app --reload
