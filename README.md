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

这样你就拥有了一个轻量级、基于 Alpine 的 x-ui-yg 容器版本，且数据可以持久化保存。
