#!/bin/bash

# 获取当前脚本所在目录的绝对路径，确保双击运行时的路径正确
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

echo "正在新窗口启动 Java 后端 (端口: 8080)..."
osascript -e "tell app \"Terminal\" to do script \"cd '$DIR/3_Backend_Java' && mvn spring-boot:run\""

echo "正在新窗口启动 Python AI 服务 (端口: 5000)..."
osascript -e "tell app \"Terminal\" to do script \"cd '$DIR/4_AIService_Python' && export HF_ENDPOINT=https://hf-mirror.com && .venv/bin/uvicorn main:app --reload --port 5000\""

echo "正在新窗口启动 Vue 管理后台 (端口: 5173)..."
osascript -e "tell app \"Terminal\" to do script \"cd '$DIR/2_AdminWeb_Vue' && npm run dev\""

echo "等待 5 秒钟，让服务飞一会儿..."
sleep 5

echo "启动 Caddy 反向代理交警 (端口: 8081)..."
cd "$DIR"
caddy start --config Caddyfile

echo "正在新窗口启动 Ngrok 内网穿透隧道..."
osascript -e "tell app \"Terminal\" to do script \"cd '$DIR' && ngrok http --domain=genna-boldhearted-dewily.ngrok-free.dev 8081\""

echo "======================================"
echo "    🚀 所有服务均已触发启动命令！"
echo "    👉 您可以直接在弹出的各个终端窗口中实时查看日志。"
echo "======================================"
