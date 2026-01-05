#!/bin/bash

# LaoWang Nav 一键更新脚本
# 使用方法：curl -fsSL https://raw.githubusercontent.com/tony-wang1990/laowang-nav/master/scripts/update.sh | bash

set -e

echo "================================"
echo "  LaoWang Nav 一键更新"
echo "================================"
echo ""

CONTAINER_NAME="laowang-nav"
IMAGE_NAME="ghcr.io/tony-wang1990/laowang-nav:latest"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ 容器 ${CONTAINER_NAME} 不存在${NC}"
    echo "请先运行安装脚本"
    exit 1
fi

echo -e "${YELLOW}[1/4] 备份当前配置...${NC}"
BACKUP_PATH="${HOME}/laowang-nav/user-data/conf.yml.backup.$(date +%Y%m%d_%H%M%S)"
if docker exec ${CONTAINER_NAME} test -f /app/user-data/conf.yml 2>/dev/null; then
    docker cp ${CONTAINER_NAME}:/app/user-data/conf.yml "${BACKUP_PATH}" 2>/dev/null || true
    [ -f "${BACKUP_PATH}" ] && echo -e "${GREEN}✓ 配置已备份: ${BACKUP_PATH}${NC}"
fi
echo ""

echo -e "${YELLOW}[2/4] 拉取最新镜像...${NC}"
docker pull ${IMAGE_NAME}
echo -e "${GREEN}✓ 最新镜像已拉取${NC}"
echo ""

echo -e "${YELLOW}[3/4] 重启容器...${NC}"
docker restart ${CONTAINER_NAME}
echo -e "${GREEN}✓ 容器已重启${NC}"
echo ""

echo -e "${YELLOW}[4/4] 检查运行状态...${NC}"
sleep 3
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ 服务运行正常${NC}"
else
    echo -e "${RED}❌ 服务启动失败，请查看日志${NC}"
    echo "docker logs ${CONTAINER_NAME}"
    exit 1
fi
echo ""

echo "================================"
echo -e "${GREEN}🎉 更新完成！${NC}"
echo "================================"
echo ""
echo "查看日志: docker logs -f ${CONTAINER_NAME}"
echo "================================"
