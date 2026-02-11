FROM alpine:latest AS builder

ARG TARGETARCH
ARG XUI_VERSION=xui_yg
ARG DOWNLOAD_URL=https://github.com/yonggekkk/x-ui-yg/releases/download/${XUI_VERSION}/x-ui-linux

WORKDIR /tmp

RUN apk add --no-cache curl tar

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

FROM alpine:latest

ENV TZ=Asia/Shanghai \
    XUI_HOME=/usr/local/x-ui \
    XUI_BIN_DIR=/usr/local/x-ui-dist \
    VERBOSE=false

# 仅安装 sh 环境下最基础的依赖
RUN apk add --no-cache \
    bash \
    libc6-compat \
    ca-certificates \
    tzdata \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

WORKDIR ${XUI_HOME}

COPY --from=builder /app_dist ${XUI_BIN_DIR}
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY journalctl /usr/bin/journalctl

# 修复换行符并授权
RUN sed -i 's/\r$//' /usr/bin/entrypoint.sh \
    && sed -i 's/\r$//' /usr/bin/journalctl \
    && chmod +x /usr/bin/entrypoint.sh /usr/bin/journalctl

EXPOSE 54321 10000-10010/tcp 10000-10010/udp

VOLUME [ "${XUI_HOME}" ]

ENTRYPOINT ["/usr/bin/entrypoint.sh"]