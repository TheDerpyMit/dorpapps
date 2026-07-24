#!/bin/bash
echo "Installing Python dependencies..."
pip install -r requirements.txt
echo "Starting Email WebSocket Server..."
python3 email_server.py
