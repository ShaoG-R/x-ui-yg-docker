# x-ui-yg Docker

这是一个基于 Alpine Linux 的轻量级 [x-ui-yg](https://github.com/yonggekkk/x-ui-yg) Docker 镜像。支持多架构 (amd64, arm64)，并提供每日自动构建。

本项目遵循 MIT License。

## 特性

*   **极度轻量**: 基于 Alpine 基础镜像构建，只包含必要依赖。
*   **多架构支持**: 同时支持 `linux/amd64` 和 `linux/arm64`。
*   **数据持久化**: 关键数据和配置可挂载到宿主机。
*   **自动更新**: 通过 GitHub Actions 进行每日构建，跟进上游更新。

## 使用方法

### 方式一：使用已发布的镜像 (推荐)

我们通过 GitHub Container Registry 发布构建好的镜像。
镜像地址: `ghcr.io/shaog-r/x-ui-yg-docker:alpine` (或者 `latest`)

#### 1. 简单运行 (Docker CLI)

```bash
docker run -d \
    --name x-ui-yg \
    -p 54321:54321 \
    -v $(pwd)/data:/usr/local/x-ui \
    -e XUI_USER=myuser \
    -e XUI_PASS=mypassword \
    ghcr.io/shaog-r/x-ui-yg-docker:alpine
```

#### 2. 使用 Docker Compose

创建或修改 `docker-compose.yml` 文件如下：

```yaml
version: '3.8'
services:
  x-ui-yg:
    # 使用发布的镜像
    image: ghcr.io/shaog-r/x-ui-yg-docker:alpine
    container_name: x-ui-yg
    restart: unless-stopped
    tty: true
    ports:
      - "54321:54321"
      - "10000-10005:10000-10005"
      - "10000-10005:10000-10005/udp"
    volumes:
      - ./data:/usr/local/x-ui
    environment:
      - XUI_USER=myuser
      - XUI_PASS=mypassword
```

然后运行：
```bash
docker-compose up -d
```

### 方式二：手动构建

如果你希望自己在本地构建镜像：

#### 1. 构建镜像

```bash
docker build -t x-ui-yg:alpine .
```

#### 2. 简单运行

```bash
docker run -d \
    --name x-ui-yg \
    -p 54321:54321 \
    -v $(pwd)/data:/usr/local/x-ui \
    -e XUI_USER=myuser \
    -e XUI_PASS=mypassword \
    x-ui-yg:alpine
```

#### 3. 使用 Docker Compose

直接在源码目录下运行即可（默认使用本地构建）：

```bash
docker-compose up -d
```

### 获取初始账号密码

若你在启动时未设置 `XUI_USER` 和 `XUI_PASS` 环境变量，容器会自动生成随机的账号和密码。可以通过查看挂载目录下的 `init.log` 文件获取：

```bash
cat data/init.log
```

输出示例：

```text
2025-12-08 13:56:05 [Info] Container entrypoint started.
2025-12-08 13:56:05 [Info] Syncing binary files...
2025-12-08 13:56:05 [Info] Binaries synced.
2025-12-08 13:56:05 [Info] Initializing configuration...
---------------------------------------------
x-ui Initial Login Info:
  Username: jkeiw3AV
  Password: WvOuqfWB
  Port    : 54321
  WebPath : /
---------------------------------------------
set username and password success
set port 54321 success
2025-12-08 13:56:05 [Info] Configuration initialized.
2025-12-08 13:56:05 [Info] Starting x-ui process...
```

**关于 `init.log` 的说明：**
1. 该日志仅用于记录容器启动时的初始化过程，包括随机生成的账号密码（若未在环境变量设置，也可能显示为 `[Set in env]`，需设置 `VERBOSE=true` 开启显示真实值）。
2. **日志滚动机制**：为防止日志无限膨胀，当日志文件超过 50KB 时，旧的 `init.log` 会被重命名为 `init.log.old`，并创建新的日志文件。
3. **安全建议**：获取到初始账号密码并登录修改后，为了安全起见，建议手动删除挂载目录下的 `init.log` 文件。

这样你就拥有了一个轻量级、基于 Alpine 的 x-ui-yg 容器版本，且数据可以持久化保存。
