#!/bin/bash

# 定义路径
DIST_DIR="/usr/local/x-ui-dist"
WORK_DIR="/usr/local/x-ui"
LOG_FILE="${WORK_DIR}/init.log"

# 定义日志滚动阈值 (字节)
# 50KB = 51200 bytes
# 既能保留最近几次的重启记录，又能防止敏感信息永久驻留
MAX_LOG_SIZE=51200

# 确保日志文件存在，避免报错
touch "$LOG_FILE"

# --- 日志滚动函数 ---
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        # 获取文件大小 (Alpine/BusyBox stat 语法)
        SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        
        if [ "$SIZE" -gt "$MAX_LOG_SIZE" ]; then
            # 滚动日志: init.log -> init.log.old
            mv -f "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
            
            # 在新日志开头记录滚动事件
            echo "$(date "+%Y-%m-%d %H:%M:%S") [Info] Log file exceeded ${MAX_LOG_SIZE} bytes. Rotated." >> "$LOG_FILE"
        fi
    fi
}

# 脚本启动时立即执行检查
rotate_log

# 定义日志辅助函数
log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") [Info] $1" >> "$LOG_FILE"
}

warn() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") [Warn] $1" >> "$LOG_FILE"
}

# 记录本次启动分割线
echo "------------------------------------------------" >> "$LOG_FILE"
log "Container entrypoint started."

# ------------------------------------------------
# 1. 运行环境准备
# ------------------------------------------------
# 从镜像自带的 /usr/local/x-ui-dist 运行，不复制二进制文件到 /usr/local/x-ui
# 这样保证 data 目录（挂载卷）只存放数据（DB/Logs），保持干净。

log "Starting container..."

# 确保工作目录存在 (存放 db, logs)
if [ ! -d "${WORK_DIR}" ]; then
    mkdir -p "${WORK_DIR}"
fi

# ------------------------------------------------
# 2. 初始化配置
# ------------------------------------------------
DB_FILE="${WORK_DIR}/x-ui.db"
# x-ui-yg 默认数据库路径为 /etc/x-ui-yg/x-ui-yg.db
# 容器重启后 /etc 会重置，导致数据库丢失，从而触发重新初始化账号密码。
# 此处建立软链接，将其指向持久化目录 /usr/local/x-ui/x-ui.db
LINK_DB_DIR="/etc/x-ui-yg"
LINK_DB_FILE="${LINK_DB_DIR}/x-ui-yg.db"

if [ ! -d "${LINK_DB_DIR}" ]; then
    mkdir -p "${LINK_DB_DIR}"
fi

# 强行建立软链接，确保应用读写的是持久化文件
ln -sf "${DB_FILE}" "${LINK_DB_FILE}"

if [ ! -f "$DB_FILE" ] || [ "${RESET_CONFIG}" = "true" ]; then
    log "Initializing configuration..."

    gen_random() {
        tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1
    }

    # Username
    if [ -n "$XUI_USER" ]; then
        RUN_USER="$XUI_USER"
        if [ "${VERBOSE}" = "true" ]; then
            DISPLAY_USER="$RUN_USER"
        else
            DISPLAY_USER="[Set in env]"
        fi
    else
        RUN_USER=$(gen_random)
        DISPLAY_USER="$RUN_USER"
    fi

    # Password
    if [ -n "$XUI_PASS" ]; then
        RUN_PASS="$XUI_PASS"
        if [ "${VERBOSE}" = "true" ]; then
            DISPLAY_PASS="$RUN_PASS"
        else
            DISPLAY_PASS="[Set in env]"
        fi
    else
        RUN_PASS=$(gen_random)
        DISPLAY_PASS="$RUN_PASS"
    fi

    # Port
    if [ -n "$XUI_PORT" ]; then
        RUN_PORT="$XUI_PORT"
        if [ "${VERBOSE}" = "true" ]; then
            DISPLAY_PORT="$RUN_PORT"
        else
            DISPLAY_PORT="[Set in env]"
        fi
    else
        RUN_PORT=54321
        DISPLAY_PORT="$RUN_PORT"
    fi

    # WebPath
    if [ -n "$XUI_PATH" ]; then
        RUN_PATH="$XUI_PATH"
        if [ "${VERBOSE}" = "true" ]; then
            DISPLAY_PATH="$RUN_PATH"
        else
            DISPLAY_PATH="[Set in env]"
        fi
    else
        RUN_PATH="/"
        DISPLAY_PATH="$RUN_PATH"
    fi

    # 将敏感信息写入日志（如果日志后续发生滚动，这些信息最终会被清理）
    echo "---------------------------------------------" >> "$LOG_FILE"
    echo "x-ui Initial Login Info:" >> "$LOG_FILE"
    echo "  Username: ${DISPLAY_USER}" >> "$LOG_FILE"
    echo "  Password: ${DISPLAY_PASS}" >> "$LOG_FILE"
    echo "  Port    : ${DISPLAY_PORT}" >> "$LOG_FILE"
    echo "  WebPath : ${DISPLAY_PATH}" >> "$LOG_FILE"
    echo "---------------------------------------------" >> "$LOG_FILE"

    # 使用 DIST_DIR 下的二进制文件进行初始化设置
    ${DIST_DIR}/x-ui setting -username "${RUN_USER}" -password "${RUN_PASS}" >> "$LOG_FILE" 2>&1
    ${DIST_DIR}/x-ui setting -port "${RUN_PORT}" >> "$LOG_FILE" 2>&1
    
    if [ "${RUN_PATH}" != "/" ]; then
        CLEAN_PATH="/$(echo "${RUN_PATH}" | sed 's|^/||')"
        ${DIST_DIR}/x-ui setting -webBasePath "${CLEAN_PATH}" >> "$LOG_FILE" 2>&1
    fi
    
    log "Configuration initialized."
else
    log "Database exists. Skipping initialization."
fi

# ------------------------------------------------
# 3. 启动应用
# ------------------------------------------------
log "Starting x-ui process..."
# 切换到 DIST_DIR 运行，确保能找到 ./bin/xray-linux-amd64 等资源
cd "${DIST_DIR}"
exec ./x-ui