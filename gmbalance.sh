#!/bin/bash

# 定义颜色输出
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
NC="\033[0m" # No Color

# 脚本出错时立即退出
set -e

# --- 步骤 1: 准备 Docker & Docker Compose 环境 ---
echo -e "${GREEN}>>> 步骤 1: 准备 Docker & Docker Compose 环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo "正在安装 Docker..."
    sudo apt-get update -y && sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
sudo systemctl start docker
sudo systemctl enable docker

if ! docker compose version &> /dev/null; then
     echo -e "${RED}Docker Compose 插件 (docker compose) 未找到, 请检查您的 Docker 安装版本!${NC}"
     exit 1
fi
echo -e "${GREEN}Docker 环境准备就绪.${NC}"

# --- 步骤 2: 部署 gemini-balance 应用 ---
echo -e "${GREEN}>>> 步骤 2: 部署 gemini-balance 应用...${NC}"

# 定义配置
DEPLOY_PATH="/opt/gemini-balance"
DATA_PATH="${DEPLOY_PATH}/data"

# 创建部署和数据目录
echo -e "${GREEN}创建部署和数据目录: ${DEPLOY_PATH} 和 ${DATA_PATH}${NC}"
sudo mkdir -p ${DATA_PATH}
cd ${DEPLOY_PATH}

# --- 步骤 3: 自动创建 .env 配置文件 (SQLite 版本) ---
echo -e "${GREEN}>>> 步骤 3: 正在写入 SQLite 专用的 .env 配置文件...${NC}"
sudo tee ${DEPLOY_PATH}/.env > /dev/null <<EOF
# 数据库配置
DATABASE_TYPE=sqlite
SQLITE_DATABASE=/app/data/gemini.db

# --- 应用核心配置 ---
API_KEYS=["AIzaSyxxxxxxxxxxxxxxxxxxx"]
ALLOWED_TOKENS=["sk-123456"]
AUTH_TOKEN=sk-123456
# For Vertex AI Platform API Keys
VERTEX_API_KEYS=["AQ.Abxxxxxxxxxxxxxxxxxxx"]
# For Vertex AI Platform Express API Base URL
VERTEX_EXPRESS_BASE_URL=https://aiplatform.googleapis.com/v1beta1/publishers/google
TEST_MODEL=gemini-1.5-flash
THINKING_MODELS=["gemini-2.5-flash-preview-04-17"]
THINKING_BUDGET_MAP={"gemini-2.5-flash-preview-04-17": 4000}
IMAGE_MODELS=["gemini-2.0-flash-exp"]
SEARCH_MODELS=["gemini-2.0-flash-exp","gemini-2.0-pro-exp"]
FILTERED_MODELS=["gemini-1.0-pro-vision-latest", "gemini-pro-vision", "chat-bison-001", "text-bison-001", "embedding-gecko-001"]
URL_CONTEXT_ENABLED=false
URL_CONTEXT_MODELS=["gemini-2.5-pro","gemini-2.5-flash","gemini-2.5-flash-lite","gemini-2.0-flash","gemini-2.0-flash-live-001"]
TOOLS_CODE_EXECUTION_ENABLED=false
SHOW_SEARCH_LINK=true
SHOW_THINKING_PROCESS=true
BASE_URL=https://generativelanguage.googleapis.com/v1beta
MAX_FAILURES=10
MAX_RETRIES=3
CHECK_INTERVAL_HOURS=1
TIMEZONE=Asia/Shanghai
TIME_OUT=300
PROXIES=[]
PROXIES_USE_CONSISTENCY_HASH_BY_API_KEY=true

# --- image_generate 相关配置 ---
PAID_KEY=AIzaSyxxxxxxxxxxxxxxxxxxx
CREATE_IMAGE_MODEL=imagen-3.0-generate-002
UPLOAD_PROVIDER=smms
SMMS_SECRET_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
PICGO_API_KEY=xxxx
PICGO_API_URL=https://www.picgo.net/api/1/upload
CLOUDFLARE_IMGBED_URL=https://xxxxxxx.pages.dev/upload
CLOUDFLARE_IMGBED_AUTH_CODE=xxxxxxxxx
CLOUDFLARE_IMGBED_UPLOAD_FOLDER=

# --- stream_optimizer 相关配置 ---
STREAM_OPTIMIZER_ENABLED=false
STREAM_MIN_DELAY=0.016
STREAM_MAX_DELAY=0.024
STREAM_SHORT_TEXT_THRESHOLD=10
STREAM_LONG_TEXT_THRESHOLD=50
STREAM_CHUNK_SIZE=5

# --- 日志配置 ---
LOG_LEVEL=info
AUTO_DELETE_ERROR_LOGS_ENABLED=true
AUTO_DELETE_ERROR_LOGS_DAYS=7
AUTO_DELETE_REQUEST_LOGS_ENABLED=false
AUTO_DELETE_REQUEST_LOGS_DAYS=30

# --- 其他配置 ---
FAKE_STREAM_ENABLED=True
FAKE_STREAM_EMPTY_DATA_INTERVAL_SECONDS=5
SAFETY_SETTINGS=[{"category": "HARM_CATEGORY_HARASSMENT", "threshold": "OFF"}, {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "OFF"}, {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "OFF"}, {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "OFF"}, {"category": "HARM_CATEGORY_CIVIC_INTEGRITY", "threshold": "BLOCK_NONE"}]
URL_NORMALIZATION_ENABLED=false
TTS_MODEL=gemini-2.5-flash-preview-tts
TTS_VOICE_NAME=Zephyr
TTS_SPEED=normal
FILES_CLEANUP_ENABLED=true
FILES_CLEANUP_INTERVAL_HOURS=1
FILES_USER_ISOLATION_ENABLED=true
EOF
echo -e "${GREEN}.env 配置文件创建成功.${NC}"

# --- 步骤 4: 创建 docker-compose.yml 并启动服务 ---
echo -e "${GREEN}>>> 步骤 4: 正在创建精简版 docker-compose.yml...${NC}"
# 如果已存在旧服务，先停止并移除
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}检测到旧的 docker-compose.yml 文件，正在停止并移除相关服务...${NC}"
    sudo docker compose down --remove-orphans
fi

# 自动创建精简的 docker-compose.yml
sudo tee ${DEPLOY_PATH}/docker-compose.yml > /dev/null <<EOF
version: '3.8'

services:
  app:
    image: ghcr.io/snailyp/gemini-balance:latest
    container_name: gemini-balance
    restart: always
    ports:
      - "8888:8000"
    volumes:
      - ./data:/app/data
    env_file:
      - .env
EOF
echo -e "${GREEN}docker-compose.yml 创建成功.${NC}"

# 启动服务
echo -e "${GREEN}正在拉取镜像并根据配置启动服务...${NC}"
sudo docker compose up -d

# --- 步骤 5: 显示最终信息和重要提示 ---
echo -e "\n${RED}!!!!!!!!!!!!!!!!!!!! 重要提示 !!!!!!!!!!!!!!!!!!!!${NC}"
echo -e "${YELLOW}部署已完成，使用的是【示例配置】。${NC}"
echo -e "${YELLOW}您必须手动修改密钥和密码才能正常使用！${NC}"
echo -e "您需要修改这些项目："
echo -e "  - ${RED}API_KEYS${NC}             (您的 Gemini API 密钥)"
echo -e "  - ${RED}AUTH_TOKEN${NC}         (访问面板的认证密钥)"
echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}🎉 gemini-balance 已成功启动! 🎉${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e "数据库类型: ${YELLOW}SQLite${NC}"
echo -e "数据存储路径: ${YELLOW}${DATA_PATH}${NC}"
echo -e "你可以通过以下地址访问 WebUI (请先前往 WebUI 修改配置):"
echo -e "${YELLOW}   http://$(hostname -I | awk '{print $1}'):8888${NC}"
echo -e "${GREEN}=======================================================${NC}"

exit 0
