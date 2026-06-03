#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "======================================"
echo "    正在为您清理旧环境，请稍候..."
echo "======================================"
brew services stop redis
pkill -f "java"
pkill -f "uvicorn"
pkill -f "vite"
caddy stop
pkill -f "ngrok"

echo "启动底层依赖 Redis..."
brew services start redis

echo "======================================"
echo "    🚀 聚合启动中..."
echo "    提示：想要关停所有服务时，直接在这个窗口按【Ctrl + C】即可！"
echo "======================================"

# 使用 concurrently 工具并列运行所有进程，并附带左侧彩色名字标签
npx concurrently \
  --kill-others \
  -n "JAVA,PYTHON,VUE,NGROK,CADDY" \
  -c "bgBlue.bold,bgMagenta.bold,bgGreen.bold,bgCyan.bold,bgYellow.bold" \
  "cd 3_Backend_Java && mvn spring-boot:run" \
  "cd 4_AIService_Python && export HF_ENDPOINT=https://hf-mirror.com && .venv/bin/uvicorn main:app --reload --port 5000" \
  "cd 2_AdminWeb_Vue && npm run dev" \
  "ngrok http --domain=genna-boldhearted-dewily.ngrok-free.dev 8081" \
  "sleep 5 && caddy run --config Caddyfile"
