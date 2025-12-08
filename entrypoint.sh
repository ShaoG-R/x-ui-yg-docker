#!/bin/sh

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
# 1. 同步二进制文件
# ------------------------------------------------
log "Syncing binary files..."

if [ ! -f "${DIST_DIR}/x-ui" ]; then
    warn "Binary source not found in ${DIST_DIR}, skipping sync."
else
    cp -f "${DIST_DIR}/x-ui" "${WORK_DIR}/"
    
    if [ ! -d "${WORK_DIR}/bin" ]; then
        mkdir -p "${WORK_DIR}/bin"
    fi
    cp -rf "${DIST_DIR}/bin/"* "${WORK_DIR}/bin/"
    
    chmod +x "${WORK_DIR}/x-ui" "${WORK_DIR}/bin/"*
    log "Binaries synced."
fi

# ------------------------------------------------
# 2. 初始化配置
# ------------------------------------------------
DB_FILE="${WORK_DIR}/x-ui.db"

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

    ${WORK_DIR}/x-ui setting -username "${RUN_USER}" -password "${RUN_PASS}" >> "$LOG_FILE" 2>&1
    ${WORK_DIR}/x-ui setting -port "${RUN_PORT}" >> "$LOG_FILE" 2>&1
    
    if [ "${RUN_PATH}" != "/" ]; then
        CLEAN_PATH="/$(echo "${RUN_PATH}" | sed 's|^/||')"
        ${WORK_DIR}/x-ui setting -webBasePath "${CLEAN_PATH}" >> "$LOG_FILE" 2>&1
    fi
    
    log "Configuration initialized."
else
    log "Database exists. Skipping initialization."
fi

# ------------------------------------------------
# 3. 启动应用
# ------------------------------------------------
log "Starting x-ui process..."
cd "${WORK_DIR}"
exec ./x-ui