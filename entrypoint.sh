#!/bin/sh

# 定义路径
DIST_DIR="/usr/local/x-ui-dist" # 镜像内置的最新程序目录
WORK_DIR="/usr/local/x-ui"      # 实际运行目录（可能是挂载卷）

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

log() {
    echo -e "${green}[Entrypoint]${plain} $1"
}

warn() {
    echo -e "${yellow}[Entrypoint]${plain} $1"
}

# ------------------------------------------------
# 1. 同步二进制文件
# ------------------------------------------------
# 无论是否挂载了数据卷，每次启动都用镜像里的最新二进制文件覆盖运行目录
# 这样可以保证你拉取新镜像重启后，x-ui核心确实更新了
# 注意：不覆盖数据库(x-ui.db)和配置(config.json)
log "Syncing binary files..."

# 复制主程序
cp -f "${DIST_DIR}/x-ui" "${WORK_DIR}/"

# 复制 bin 目录 (xray 核心)，如果目录不存在则创建
if [ ! -d "${WORK_DIR}/bin" ]; then
    mkdir -p "${WORK_DIR}/bin"
fi
cp -rf "${DIST_DIR}/bin/"* "${WORK_DIR}/bin/"

# 确保有执行权限
chmod +x "${WORK_DIR}/x-ui" "${WORK_DIR}/bin/"*

# ------------------------------------------------
# 2. 初始化配置 (仅在数据库不存在或强制重置时)
# ------------------------------------------------
DB_FILE="${WORK_DIR}/x-ui.db"

if [ ! -f "$DB_FILE" ] || [ "${RESET_CONFIG}" = "true" ]; then
    log "Initializing configuration..."

    # 生成随机值的辅助函数
    gen_random() {
        tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1
    }

    # 获取配置或生成默认值
    # 如果没传环境变量，则像原脚本一样生成随机账号密码，提高安全性
    RUN_USER=${XUI_USER:-$(gen_random)}
    RUN_PASS=${XUI_PASS:-$(gen_random)}
    RUN_PORT=${XUI_PORT:-54321}
    RUN_PATH=${XUI_PATH:-/}

    log "---------------------------------------------"
    log "Setting up admin account:"
    log "Username: ${RUN_USER}"
    log "Password: ${RUN_PASS}"
    log "Port    : ${RUN_PORT}"
    log "WebPath : ${RUN_PATH}"
    log "---------------------------------------------"

    # 应用配置
    ${WORK_DIR}/x-ui setting -username "${RUN_USER}" -password "${RUN_PASS}"
    ${WORK_DIR}/x-ui setting -port "${RUN_PORT}"
    
    # 路径清理
    if [ "${RUN_PATH}" != "/" ]; then
        # 确保路径以 / 开头
        CLEAN_PATH="/$(echo "${RUN_PATH}" | sed 's|^/||')"
        ${WORK_DIR}/x-ui setting -webBasePath "${CLEAN_PATH}"
    fi
else
    log "Database exists. Skipping initialization."
    if [ -n "$XUI_USER" ] || [ -n "$XUI_PORT" ]; then
        warn "Environment variables for User/Pass/Port are IGNORED because database exists."
        warn "To force reset, set RESET_CONFIG=true"
    fi
fi

# ------------------------------------------------
# 3. 启动应用
# ------------------------------------------------
log "Starting x-ui..."
cd "${WORK_DIR}"
exec ./x-ui