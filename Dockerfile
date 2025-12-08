# -----------------------------------------------------
# Stage 1: Downloader (构建层)
# 用于下载和解压资源，这层产生的垃圾文件不会进入最终镜像
# -----------------------------------------------------
FROM alpine:latest AS builder

ARG TARGETARCH
ARG XUI_VERSION=xui_yg
# 指定下载源，方便后期维护
ARG DOWNLOAD_URL=https://github.com/yonggekkk/x-ui-yg/releases/download/${XUI_VERSION}/x-ui-linux

WORKDIR /tmp

RUN apk add --no-cache curl tar

# 根据架构下载并整理文件结构
RUN set -ex \
    && case "${TARGETARCH}" in \
        "amd64") ARCH="amd64" ;; \
        "arm64") ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
    && echo "Downloading x-ui for ${ARCH}..." \
    && curl -L -H "Cache-Control: no-cache" -o x-ui.tar.gz ${DOWNLOAD_URL}-${ARCH}.tar.gz \
    && tar zxvf x-ui.tar.gz \
    && mv x-ui /app_dist \
    && chmod +x /app_dist/x-ui /app_dist/bin/xray-linux-${ARCH}

# -----------------------------------------------------
# Stage 2: Runtime (运行层)
# 最终产物，保持极致轻量
# -----------------------------------------------------
FROM alpine:latest

# 环境变量
ENV TZ=Asia/Shanghai \
    XUI_HOME=/usr/local/x-ui \
    XUI_BIN_DIR=/usr/local/x-ui-dist

# 安装运行时必需依赖
# libc6-compat: 解决 glibc 二进制兼容性
# ca-certificates: 解决 HTTPS 请求证书问题
# tzdata: 解决日志时间不对的问题
RUN apk add --no-cache \
    libc6-compat \
    ca-certificates \
    tzdata \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

WORKDIR ${XUI_HOME}

# 从构建层只复制处理好的文件到镜像的一个备份目录
COPY --from=builder /app_dist ${XUI_BIN_DIR}
COPY entrypoint.sh /usr/bin/entrypoint.sh

RUN chmod +x /usr/bin/entrypoint.sh

# 暴露端口：面板端口 + 常用代理端口范围
EXPOSE 54321 10000-10010/tcp 10000-10010/udp

VOLUME [ "${XUI_HOME}" ]

ENTRYPOINT ["/usr/bin/entrypoint.sh"]