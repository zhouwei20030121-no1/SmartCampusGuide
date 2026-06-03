#!/bin/bash

echo "======================================"
echo "    正在为您彻底关停所有后端服务..."
echo "======================================"

brew services stop redis
pkill -f "java"
pkill -f "uvicorn"
pkill -f "vite"
caddy stop
pkill -f "ngrok"

echo "======================================"
echo "    🛑 所有服务均已安全退出！"
echo "    您可以手动关掉桌面上的那些终端黑框框了。"
echo "======================================"
